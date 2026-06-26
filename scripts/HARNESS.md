# 切换 Harness / IM 平台

## 换 Harness（Claude Code → Codex / OpenClaw / 其他）

改 2 处：

### 1. deploy.sh — 启动命令

```bash
# Claude Code
tmux send-keys "claude" C-m

# Codex CLI
tmux send-keys "codex exec" C-m

# OpenClaw
tmux send-keys "openclaw serve" C-m
```

### 2. msg-watcher.sh — 忙碌检测正则

```bash
# Claude Code (❯ prompt + thinking/esc to interrupt)
grep -qE '(thinking|still|Esc to interrupt|ctrl\+o to expand|Do you want to|Waiting…)'
grep -qE '(❯|[$#>] )'

# Codex CLI (▸ prompt + Working/Generating)
grep -qE '(Working…|Generating…|Processing)'
grep -qE '(▸|❯)'

# OpenClaw (根据实际 UI 调整)
grep -qE '(Processing|Working|Thinking)'
```

### 3. 配置文件（可选）

```bash
# Claude Code → .claude/settings.local.json + .claude/CLAUDE.md
# Codex CLI  → .codex/config.yaml
# OpenClaw   → openclaw.yaml
```

其余全部复用：tmux、msg-watcher.sh、supervisor.sh、知识库、roles。

## 换 IM 平台（Lark → 企业微信 / Slack / 其他）

改 2 处：

### 1. 收消息 — 把消息投递到 messages/

```
Lark:      lark-cli event +subscribe --output-dir messages/
企业微信:  启动 HTTP server 接收 webhook → 写入 messages/
Slack:     socket mode / events API → 写入 messages/
通用:      任何能 POST 到 messages/ 目录的机制
```

最简单通用方案——启动一个 HTTP server 接收 webhook：

```bash
ncat -l -p 8080 -c 'cat > messages/$(date +%s).json'
```

### 2. 发消息 — 改 agents/oncall-agent/AGENTS.md 中的回复命令

```
Lark:      lark-cli api POST /open-apis/im/v1/messages ...
企业微信:   curl -X POST "https://qyapi.weixin.qq.com/.../webhook/send?key=..." ...
Slack:     curl -X POST "https://hooks.slack.com/..." ...
通用:      任何 curl/webhook/SDK 命令
```
