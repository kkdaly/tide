# AI Agent Platform / AI Agent 平台

> 一套通用 AI Agent 基础设施。不依赖 RAG，不依赖编排框架。事件驱动的多 Agent 调度平台，不局限于任何特定场景。
>
> A general-purpose AI agent infrastructure. **No RAG, no orchestration frameworks.** Just tmux + bash + prompts. Event-driven multi-agent scheduling — not tied to any specific domain.

## 这是什么 / What It Does

把多个 AI Agent 作为常驻 tmux 会话运行。消息（飞书、Slack、webhook 等）落入目录，watcher 唤醒 gateway agent，gateway 智能判断后自己回答或委托给后台专业 agent，通过文件传递任务。

Runs multiple AI agents as long-lived tmux sessions. Messages land in a directory, a watcher wakes the gateway agent, which intelligently routes tasks to specialist agents via file-based IPC.

```
消息/Message → messages/ → msg-watcher → gateway-agent (AI 路由/dispatcher)
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    ▼                         ▼                         ▼
              直接回复/Direct            code-analyzer              code-review
              查知识库+代码              深度代码分析               PR 审查
                                        deploy-monitor            (可扩展/extensible)
                                        发布巡检
```

## 快速开始 / Quick Start

```bash
# 1. 装依赖 / Install prerequisites
brew install tmux          # macOS
sudo apt install tmux      # Linux

# 2. 克隆部署 / Clone and deploy
git clone <repo> ai-agent && cd ai-agent
cp .env.example .env
./scripts/deploy.sh

# 3. 订阅 IM 消息 / Subscribe to messages (Lark)
npm install -g @larksuite/cli
lark-cli config init
lark-cli auth login --recommend
lark-cli event +subscribe --output-dir messages/
```

给 Bot 发消息，它就会回复。 / Send a message to your bot — it replies.

## 切换 Harness / Switch Harness

```bash
HARNESS=codex ./scripts/deploy.sh     # Codex CLI
HARNESS=trae ./scripts/deploy.sh      # Trae CLI
HARNESS=openclaw ./scripts/deploy.sh  # OpenClaw
# 默认 Claude Code / Defaults to Claude Code
```

详见 / See `scripts/HARNESS.md`.

## 架构 / Architecture

| 层/Layer | 做什么/What | 怎么做/How |
|-----------|-------------|------------|
| 调度/Scheduling | tmux 会话 | 5 个常驻 session，每个 agent 一个 |
| 事件/Event loop | bash watcher | 轮询 `messages/` 和 `tasks/`，agent 空闲时唤醒 |
| 路由/Routing | AI 判断 | Gateway 读消息，判断：自己答还是委托 |
| 通信/IPC | JSON 文件 | `tasks/{type}-req-{id}.json` → `tasks/{type}-res-{id}.json` |
| 监控/Supervision | supervisor.sh | 60s 巡检：session 存活、未卡死、未循环 |

## 内置 Agent / Built-in Agents

| Agent | Session | 触发/Trigger | 职责/Role |
|-------|---------|-------------|-----------|
| Gateway | `gateway-agent` | msg-watcher | 消息入口，AI 路由 / Message entry, dispatcher |
| Code Analyzer | `code-analyzer` | code-watcher | 深度代码分析 / Deep code analysis |
| Code Review | `code-review-agent` | review-watcher | PR 审查 / PR review |
| Deploy Monitor | `deploy-monitor` | deploy-watcher | 发布巡检 / Release inspection |
| Supervisor | `supervisor` | 定时循环 | 健康监控 / Health monitoring |

## 定制 / Customize

1. **换场景 / Change scenario** — 编辑 `agents/gateway-agent/CLAUDE.md`（身份）和 `AGENTS.md`（操作）
2. **加 Agent / Add agent** — 在 `agents/<name>/` 下创建 CLAUDE.md + AGENTS.md，deploy.sh 加 session 和 watcher
3. **填知识库 / Fill knowledge** — 编辑 `knowledge-base/` 写项目文档
4. **关联代码 / Link code** — `ln -s /your/repo repos/` 让 agent 能读源码
5. **换 IM / Switch IM** — 改 `agents/gateway-agent/AGENTS.md` 中的回复命令

## 项目结构 / Project Structure

```
.
├── README.md                     ← 本文件 / This file
├── CONVENTIONS.md                ← Agent 底座 prompt
├── AGENTS.md                     ← AI 指令 / AI instructions
├── .env.example                  ← 配置模板 / Config template
├── agents/                       ← Agent 身份和指令 / Identities & instructions
├── knowledge-base/               ← 项目知识库 / Your docs
├── scripts/                      ← 部署、watcher、监工 / Deploy, watchers, supervisor
├── tasks/                        ← Agent 间任务传递 / Inter-agent task files
├── repos/                        ← 代码仓库 symlink / Code symlinks
├── messages/                     ← IM 消息落地 / Message landing
└── worklogs/                     ← 问答记录 / Q&A records
```

## License

MIT
