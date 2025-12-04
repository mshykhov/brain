# Telegram Setup

## Step 1: Create Bot

1. Open Telegram, search for `@BotFather`
2. Send `/newbot`
3. Enter bot name: `Homelab Alerts`
4. Enter username: `homelab_alerts_bot` (must end with `bot`)
5. Copy the **Bot Token** (save to Doppler as `TELEGRAM_BOT_TOKEN`)

```
Example token: 1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
```

## Step 2: Create Group with Topics

1. Create new group: `Homelab Alerts`
2. Add your bot to the group
3. Make bot an **admin** (required for sending to topics)
4. Enable Topics:
   - Group Settings → Topics → Enable

## Step 3: Create Topics

Create these topics in the group:

| Topic | Purpose | Notifications |
|-------|---------|---------------|
| 🔴 Critical | Immediate action required | ON (with sound) |
| 🟠 Warning | Needs attention soon | OFF (muted) |
| ⚪ Info | Informational, resolved | OFF (muted) |
| 🚀 Deploys | ArgoCD deployments | OFF (muted) |

## Step 4: Get Chat ID and Topic IDs

### Method 1: Via Bot API

1. Send a message to each topic in your group
2. Open in browser:
   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
3. Find your messages in the JSON response:

```json
{
  "message": {
    "chat": {
      "id": -1001234567890,  // ← TELEGRAM_CHAT_ID
      "title": "Homelab Alerts"
    },
    "message_thread_id": 2,  // ← Topic ID
    "text": "test"
  }
}
```

### Method 2: Via @RawDataBot

1. Add `@RawDataBot` to your group temporarily
2. Send message in each topic
3. Bot will reply with JSON containing IDs
4. Remove bot after getting IDs

## Step 5: Save to Doppler

Add these secrets to Doppler (`shared` config):

| Key | Example Value | Description |
|-----|---------------|-------------|
| `TELEGRAM_BOT_TOKEN` | `1234567890:ABC...xyz` | Bot token |
| `TELEGRAM_CHAT_ID` | `-1001234567890` | Group ID (negative) |
| `TELEGRAM_TOPIC_CRITICAL` | `2` | Critical topic thread ID |
| `TELEGRAM_TOPIC_WARNING` | `3` | Warning topic thread ID |
| `TELEGRAM_TOPIC_INFO` | `4` | Info topic thread ID |
| `TELEGRAM_TOPIC_DEPLOYS` | `5` | Deploys topic thread ID |

## Step 6: Test Bot

Test that bot can send to topics:

```bash
# Set variables
BOT_TOKEN="your_token"
CHAT_ID="-1001234567890"
TOPIC_ID="2"

# Send test message
curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": ${CHAT_ID},
    \"message_thread_id\": ${TOPIC_ID},
    \"text\": \"Test alert from curl\",
    \"parse_mode\": \"HTML\"
  }"
```

Expected response:
```json
{"ok": true, "result": {...}}
```

## Troubleshooting

### Bot can't send messages

1. Ensure bot is **admin** in the group
2. Check bot has "Post Messages" permission
3. Verify chat_id is negative for groups

### Topic ID not working

1. Topics must be enabled in group settings
2. message_thread_id is different from topic name
3. Use getUpdates to find correct thread IDs

### "Chat not found" error

1. Bot must be member of the group
2. Send at least one message to group first
3. Use getUpdates to get correct chat_id

## Security Notes

- Never commit bot token to Git
- Store all IDs in Doppler
- Bot token gives full control - treat as password
- Consider separate bot for production vs dev

## Next Steps

→ [02-alertmanager-config.md](02-alertmanager-config.md) - Configure Alertmanager routing
