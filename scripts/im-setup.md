# 小说阅读平台 AI Oncall Agent — 部署指南

## 架构概览

```
Lark 消息 → messages/ 目录 → msg-watcher (1s 轮询) → tmux send-keys → Agent 唤醒处理
                                                    ↑
                                              监工 Agent (60s 巡检)
```

**两个唤醒机制：**
- **msg-watcher（外部，1s）：** bash 脚本轮询 messages/ 目录，发现新消息通过 tmux send-keys 注入唤醒指令。不消耗 Agent 上下文，这是主要唤醒通道。
- **/loop（内部，已废弃）：** Claude Code 自带定时器，长时间无消息会空耗 token，已被 msg-watcher 替代。

## 前置条件

- Linux 或 macOS（tmux 可用）
- Node.js 22+（lark-cli 依赖）
- tmux 已安装
- 飞书 App 已创建，具备以下权限：
  - `im:message:readonly`
  - `im:message.group_at_msg.include_bot:readonly`

## 首次部署

```bash
cd /Users/kkdaly/Desktop/test

# 1. 安装 Lark CLI
npm install -g @larksuite/cli

# 2. 配置飞书凭证（交互式，需 App ID / App Secret）
lark-cli config init

# 3. 授权登录
lark-cli auth login --recommend

# 4. 一键部署（tmux 会话 + 监工 + msg-watcher）
./scripts/deploy.sh

# 5. 启动消息订阅（另开终端，会阻塞在前台）
lark-cli event +subscribe --output-dir messages/

# 6. 脱离 oncall-agent session，让 Agent 后台运行
#    在 oncall-agent tmux 窗口里按 Ctrl+B 然后按 D
```

## 重新部署

```bash
cd /Users/kkdaly/Desktop/test

# 清理旧的
tmux kill-session -t oncall-agent 2>/dev/null
tmux kill-session -t supervisor 2>/dev/null
tmux kill-session -t code-analyzer 2>/dev/null
pkill -f msg-watcher.sh

# 重新部署
./scripts/deploy.sh

# 重新订阅消息
lark-cli event +subscribe --output-dir messages/
```

## 验证

```bash
# 查看 tmux 会话
tmux ls

# 查看 msg-watcher 进程
ps aux | grep msg-watcher | grep -v grep

# 查看 Agent 状态
tmux capture-pane -t oncall-agent -p -S -10

# 手动触发
echo '{"event":{"message":{"content":"{\"text\":\"测试\"}"}}}' > messages/test.json
# 等 1-2 秒，检查 Agent 是否处理
```

## 切换 Agent 角色

```bash
./scripts/switch-agent.sh list                # 查看可用角色
./scripts/switch-agent.sh code-review         # 切换到 Code Review Agent
./scripts/switch-agent.sh deploy-monitor      # 切换到发布巡检 Agent
./scripts/switch-agent.sh oncall-novels       # 切回 Oncall Agent
```

切换后 Agent 自动收到通知重新加载配置。详见 `AGENTS.md`。

## 日常操作

| 操作 | 命令 |
|------|------|
| 查看 Agent 输出 | `tmux attach -t oncall-agent` |
| 脱离 session | `Ctrl+B` 然后 `D` |
| 查看监工日志 | `tmux attach -t supervisor` |
| 手动唤醒 Agent | `tmux send-keys -t oncall-agent "检查 messages/" Enter` |
| 停止全部 | `./scripts/deploy.sh` 末尾有停止命令 |

## 关键设计

- **msg-watcher 不会在人工 attach 时唤醒 Agent**——检测到 `tmux list-clients` 有人连接就跳过，防止打断你的操作。所以日常要让 Agent 自己跑就 detach。
- **busy 检测看 `❯` prompt**——Agent 输出末尾有 Claude Code 的 `❯` 说明空闲，否则假定正在处理中，msg-watcher 会等下一轮。
- **消息文件按 Lark event_id 命名**——Agent 处理后删文件，`.gitkeep` 保留目录结构，msg-watcher 排除 `.gitkeep` 不计入消息数。

## 踩过的坑

### 1. Agent 收到消息但不回复

**症状：** 消息落到了 messages/ 目录，msg-watcher 在跑，但 Agent 没有任何反应。

**原因：** `is_agent_busy()` 只认识 shell prompt（`$` `#` `>`），不认识 Claude Code 的 `❯` prompt。所以每轮检测都判定 Agent "忙碌"，永远不发唤醒键。

**修复：** 把检测逻辑从 `grep -qE '[$#>] $'` 改为 `grep -qE '(❯|[$#>] )'`，同时把检测范围从最后一行扩展到最后 5 行（Claude Code 的 `❯` 后面可能跟着其他 UI 元素）。

### 2. /loop 空转消耗 token

**症状：** 用 `/loop 60s` 让 Agent 定时检查消息，长时间无消息时上下文逐渐膨胀，token 消耗飞快。

**原因：** `/loop` 每次醒来都是一次完整的 AI 调用，即使只是"无新消息"也要消耗 token。而且 /loop 会在 compaction 时把上下文挤掉。

**修复：** 取消 `/loop`，完全依赖外部 msg-watcher.sh 通过 `tmux send-keys` 事件驱动唤醒。Agent 只在有新消息时才工作，零空转消耗。

### 3. msg-watcher 轮询间隔太慢

**症状：** 用户发消息后要等 30 秒才有回复，体验很差。

**原因：** deploy.sh 里 msg-watcher 默认 `sleep 30`。

**修复：** 改为 `sleep 1`，消息到达后最多 1 秒触发唤醒。

### 4. tmux macOS 兼容性

**症状：** macOS 13 Ventura 上 `brew install tmux` 失败——Homebrew 不给旧版本提供预编译包，源码构建也因依赖链失败。

**解决：** 换到较新的 macOS 版本（14+）或 Linux，`brew install tmux` / `apt install tmux` 一行搞定。

### 5. lark-cli 消息输出路径

**症状：** 在 `~` 目录下执行 `lark-cli event +subscribe --output-dir messages/`，消息写到了 `~/messages/` 而不是项目的 `messages/`。

**解决：** 先 `cd` 到项目根目录再执行，或使用绝对路径 `--output-dir /path/to/project/messages/`。

### 6. 人工 attach 导致 Agent 不响应

**症状：** `tmux attach -t oncall-agent` 连上去看 Agent 状态，结果 Agent 再也不处理新消息了。

**原因：** 这是设计行为，不是 bug。`is_human_attached()` 检测到有人连在 session 上就跳过唤醒，防止 `send-keys` 打断你的键盘输入。

**解决：** 看完后按 `Ctrl+B D` 脱离 session，msg-watcher 恢复唤醒。
