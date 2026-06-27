#!/bin/bash
# 消息流水线：监控消息目录 → 检测 Agent 状态 → 唤醒
# 由 deploy.sh 后台驱动，HARNESS 环境变量控制 busy 检测正则

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/harness-presets.sh"

MESSAGES_DIR="$ROOT_DIR/messages"
AGENT_SESSION="gateway-agent"
COOLDOWN_SEC="${POLL_COOLDOWN:-15}"

is_agent_busy() {
    local output
    output=$(tmux capture-pane -t "$AGENT_SESSION" -p -S -20 2>/dev/null)

    if [ -z "$output" ]; then
        return 1
    fi

    local recent
    recent=$(echo "$output" | tail -8)

    if echo "$recent" | grep -qE "$HARNESS_BUSY_PATTERN"; then
        return 0
    fi

    if echo "$recent" | tail -3 | grep -qE "$HARNESS_IDLE_PATTERN"; then
        return 1
    fi

    return 0
}

# 检查是否有人工 attach
is_human_attached() {
    tmux list-clients -t "$AGENT_SESSION" 2>/dev/null | grep -q .
}

# 主循环
main() {
    # tmux 不可用则静默退出
    if ! command -v tmux &>/dev/null; then
        exit 0
    fi

    # 检查是否有新消息
    local msg_count
    msg_count=$(find "$MESSAGES_DIR" -type f -not -name '.gitkeep' 2>/dev/null | wc -l | tr -d ' ')

    if [ "$msg_count" -eq 0 ]; then
        return
    fi

    # 冷却期：上次唤醒后 15 秒内不再发，防止指令轰炸
    local cooldown_file="/tmp/msg_watcher_cooldown"
    if [ -f "$cooldown_file" ]; then
        local last_wake now elapsed
        last_wake=$(cat "$cooldown_file" 2>/dev/null)
        now=$(date +%s)
        elapsed=$((now - last_wake))
        if [ "$elapsed" -lt "$COOLDOWN_SEC" ]; then
            return
        fi
    fi

    # Agent 忙碌 → 等下一轮
    if is_agent_busy; then
        return
    fi

    # Agent 空闲 + 有消息 → 唤醒
    date +%s > "$cooldown_file"
    tmux send-keys -t "$AGENT_SESSION" "读msg并lark回复"
    tmux send-keys -t "$AGENT_SESSION" C-m
}

main
