# IM 消息订阅配置指南

根据你选择的 IM 平台完成以下配置：

## Lark（飞书）

```bash
# 安装 Lark CLI
# 订阅消息到 messages/ 目录
lark-cli event subscribe --output-dir messages/
```

需要先创建 Lark App 并配置权限：
- `im:message:readonly` — 读取消息
- `im:message.group_at_msg.include_bot:readonly` — 接收群内 at Bot 消息
- 配置 Event Subscription 指向你的服务器

## Slack

```bash
# 使用 Slack CLI 或 webhook
# 将消息写入 messages/ 目录
```

需要创建 Slack App 并配置：
- Event Subscriptions（message.channels, message.groups）
- OAuth tokens

## 通用方式：Webhook

如果没有 CLI 工具，可以通过 Webhook 接收消息：

```bash
# 启动一个简单的 HTTP server 接收 webhook
# 将消息体写入 messages/ 目录
# 示例：ncat -l -p 8080 -c 'cat > messages/$(date +%s).json'
```

## 配置完成后

将 msg-watcher.sh 加入定时运行：

```bash
# 方式一：cron 每 30 秒
# */1 * * * * /path/to/scripts/msg-watcher.sh
# */1 * * * * sleep 30 && /path/to/scripts/msg-watcher.sh

# 方式二：后台 while 循环
# nohup bash -c 'while true; do /path/to/scripts/msg-watcher.sh; sleep 30; done' &

# 方式三：systemd timer
```
