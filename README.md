# AI Agent Platform

A general-purpose AI agent infrastructure. **No RAG, no orchestration frameworks.** Just tmux + bash + prompts. Event-driven multi-agent scheduling platform — not tied to any specific scenario.

## What It Does

Runs multiple AI agents as long-lived tmux sessions. Incoming messages (from Lark, Slack, webhook, etc.) land in a directory, a watcher wakes the gateway agent, which intelligently routes tasks to specialist agents via file-based IPC.

```
Message → messages/ → msg-watcher → gateway-agent (AI dispatcher)
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
              Direct reply       code-analyzer        code-review
                                deploy-monitor       (extensible)
```

## Quick Start

```bash
# 1. Install prerequisites
brew install tmux          # macOS
sudo apt install tmux      # Linux

# 2. Clone and deploy
git clone <repo> ai-agent && cd ai-agent
cp .env.example .env
./scripts/deploy.sh

# 3. Subscribe to IM messages (Lark example)
npm install -g @larksuite/cli
lark-cli config init
lark-cli auth login --recommend
lark-cli event +subscribe --output-dir messages/
```

Send a message to your bot — it replies.

## Switch Harness

```bash
HARNESS=codex ./scripts/deploy.sh     # Codex CLI
HARNESS=trae ./scripts/deploy.sh      # Trae CLI
HARNESS=openclaw ./scripts/deploy.sh  # OpenClaw
# Defaults to Claude Code
```

See `scripts/HARNESS.md` for details.

## Architecture

| Layer | What | How |
|-------|------|-----|
| **Scheduling** | tmux sessions | 5 persistent sessions, one per agent |
| **Event loop** | bash watchers | Poll `messages/` and `tasks/`, wake agents when idle |
| **Routing** | AI dispatcher | Gateway agent reads messages, decides: answer or delegate |
| **IPC** | JSON files | `tasks/{type}-req-{id}.json` → `tasks/{type}-res-{id}.json` |
| **Supervision** | supervisor.sh | 60s health checks: session alive, not stuck, not looping |

## Built-in Agents

| Agent | Session | Trigger | Role |
|-------|---------|---------|------|
| Gateway | `gateway-agent` | msg-watcher | Message entry, AI routing |
| Code Analyzer | `code-analyzer` | code-watcher | Deep code analysis |
| Code Review | `code-review-agent` | review-watcher | PR review |
| Deploy Monitor | `deploy-monitor` | deploy-watcher | Release inspection |
| Supervisor | `supervisor` | cron-style loop | Health monitoring |

## Customize

1. **Change scenario** — edit `agents/gateway-agent/CLAUDE.md` (who) and `AGENTS.md` (how)
2. **Add agent** — create `agents/<name>/` with CLAUDE.md + AGENTS.md, add session in `deploy.sh`
3. **Fill knowledge** — edit `knowledge-base/` with your project docs
4. **Link code** — `ln -s /your/repo repos/` so agents can read source
5. **Switch IM** — change the reply command in `agents/gateway-agent/AGENTS.md`

## Project Structure

```
.
├── README.md                     ← This file
├── CONVENTIONS.md                ← Base prompt for all agents
├── AGENTS.md                     ← AI agent instructions
├── .env.example                  ← Config template
├── agents/                       ← Agent identities and instructions
├── knowledge-base/               ← Your project documentation
├── scripts/                      ← Deploy, watchers, supervisor
├── tasks/                        ← Inter-agent task files
├── repos/                        ← Code repo symlinks
├── messages/                     ← IM message landing
└── worklogs/                     ← Q&A records
```

## License

MIT
