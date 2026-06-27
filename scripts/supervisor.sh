#!/bin/bash
# 监工循环：每 60 秒检查 Agent 状态，异常时告警
# 启动方式：在 supervisor tmux session 中 while true; do ./scripts/supervisor.sh; sleep 60; done

SUPERVISOR_DIR="$(dirname "$0")/.."
MESSAGES_DIR="$SUPERVISOR_DIR/messages"

# 告警函数 —— 按你的 IM 平台实现
alert() {
    local level="$1"  # warn / critical
    local title="$2"
    local detail="$3"
    local date_str
    date_str=$(date "+%Y-%m-%d %H:%M:%S")

    echo "[$date_str] [$level] $title"
    echo "$detail"
    echo "---"

    # TODO: 替换为你使用的 IM 通知方式
    # 例如 Lark webhook:
    # curl -X POST "$WEBHOOK_URL" -H "Content-Type: application/json" \
    #   -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"[$level] $title\n$detail\"}}"
}

# 检查是否有人工 attach 到 session
is_human_attached() {
    local session="$1"
    tmux list-clients -t "$session" 2>/dev/null | grep -q .
}

check_session() {
    local session="$1"
    local label="$2"
    local staleness_sec="${3:-180}"

    # 检查 session 是否存在
    if ! tmux has-session -t "$session" 2>/dev/null; then
        alert "warn" "$label session 不存在" "session: $session"
        return 1
    fi

    # 有人工 attach → 不干预，退出检查
    if is_human_attached "$session"; then
        return 0
    fi

    # 卡死检测：通过 session 最后活动时间
    local last_activity now elapsed
    last_activity=$(tmux display-message -t "$session" -p '#{session_activity}' 2>/dev/null)
    now=$(date +%s)
    if [ -n "$last_activity" ] && [ "$last_activity" -gt 0 ]; then
        elapsed=$((now - last_activity))
        if [ "$elapsed" -gt "$staleness_sec" ]; then
            alert "critical" "$label 疑似卡死: ${elapsed}秒无活动" "session: $session (阈值: ${staleness_sec}秒)"
            return 1
        fi
    fi

    # 获取最近输出
    local output
    output=$(tmux capture-pane -t "$session" -p -S -50 2>/dev/null)

    if [ -z "$output" ]; then
        alert "warn" "$label session 无输出" "session: $session"
        return 1
    fi

    # 检查是否有重复行（循环检测的简单启发式）
    local repeated
    repeated=$(echo "$output" | tail -20 | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    if [ "$repeated" -gt 5 ]; then
        alert "critical" "$label 疑似循环" "session: $session\n最近输出:\n$output"
        return 1
    fi

    return 0
}

main() {
    # tmux 不可用则静默退出
    if ! command -v tmux &>/dev/null; then
        exit 0
    fi

    local date_str
    date_str=$(date "+%Y-%m-%d %H:%M:%S")

    # 检查消息积压
    local msg_count
    msg_count=$(find "$MESSAGES_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$msg_count" -gt 10 ]; then
        alert "warn" "消息积压: $msg_count 条" "目录: $MESSAGES_DIR"
    fi

    # 检查各 session
    check_session "gateway-agent" "Gateway" 180
    check_session "code-analyzer" "CodeAnalyzer" 300
    check_session "code-review-agent" "CodeReview" 300
    check_session "deploy-monitor" "DeployMonitor" 300

    echo "[$date_str] supervisor check complete"
}

main
