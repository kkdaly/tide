#!/bin/bash
# PR 审查 Agent 唤醒脚本
# 监控 tasks/ 目录，发现审查请求时唤醒 code-review-agent

TASKS_DIR="$(dirname "$0")/../tasks"
AGENT_SESSION="code-review-agent"
COOLDOWN_SEC="${POLL_COOLDOWN:-15}"

is_agent_busy() {
    local output
    output=$(tmux capture-pane -t "$AGENT_SESSION" -p -S -20 2>/dev/null)

    if [ -z "$output" ]; then
        return 1
    fi

    local recent
    recent=$(echo "$output" | tail -8)

    if echo "$recent" | grep -qE '(thinking|still|Esc to interrupt|ctrl\+o to expand|Do you want to|Waiting…)'; then
        return 0
    fi

    if echo "$recent" | tail -3 | grep -qE '(❯|[$#>] )'; then
        return 1
    fi

    return 0
}

main() {
    if ! command -v tmux &>/dev/null; then
        exit 0
    fi

    if ! tmux has-session -t "$AGENT_SESSION" 2>/dev/null; then
        exit 0
    fi

    local task_count
    task_count=$(find "$TASKS_DIR" -type f -name 'review-req-*.json' 2>/dev/null | wc -l | tr -d ' ')

    if [ "$task_count" -eq 0 ]; then
        return
    fi

    local cooldown_file="/tmp/review_watcher_cooldown"
    if [ -f "$cooldown_file" ]; then
        local last_wake now elapsed
        last_wake=$(cat "$cooldown_file" 2>/dev/null)
        now=$(date +%s)
        elapsed=$((now - last_wake))
        if [ "$elapsed" -lt "$COOLDOWN_SEC" ]; then
            return
        fi
    fi

    if is_agent_busy; then
        return
    fi

    date +%s > "$cooldown_file"
    tmux send-keys -t "$AGENT_SESSION" "读tasks/review-req并审查代码"
    tmux send-keys -t "$AGENT_SESSION" C-m
}

main
