# ArgoCD Notifications

## Overview

ArgoCD has built-in notifications controller. Send deployment events to Telegram and critical alerts to Pushover.

## Enable Notifications

ArgoCD notifications enabled by default in recent versions. Verify:

```bash
kubectl get deployment -n argocd argocd-notifications-controller
```

## Configuration

### Step 1: Create Secret

```yaml
# charts/credentials/templates/argocd-telegram.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: argocd-telegram-secret
  namespace: argocd
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: argocd-notifications-secret
    creationPolicy: Owner
  data:
    - secretKey: telegram-token
      remoteRef:
        key: TELEGRAM_BOT_TOKEN
    - secretKey: pushover-api-token
      remoteRef:
        key: PUSHOVER_API_TOKEN
```

### Step 2: ConfigMap

```yaml
# charts/argocd-config/templates/argocd-notifications-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Services
  service.telegram: |
    token: $telegram-token

  # Pushover webhook (token in URL for secret substitution)
  service.webhook.pushover-critical: |
    url: https://api.pushover.net/1/messages.json?token=$pushover-api-token
    headers:
      - name: Content-Type
        value: application/x-www-form-urlencoded

  # Telegram templates
  template.app-sync-failed: |
    message: |
      ❌ *{{ .app.metadata.name }}*
      🚫 Sync failed
      🏷 Namespace: `{{ .app.spec.destination.namespace }}`
      {{- if .app.status.operationState.message }}
      ⚠️ Error: {{ .app.status.operationState.message | trunc 200 }}
      {{- end }}
      🔗 [View Details]({{ .context.argocdUrl }}/applications/{{ .app.metadata.name }}?operation=true)

  # Pushover template (form-urlencoded, urlquery for escaping)
  template.app-sync-failed-pushover: |
    webhook:
      pushover-critical:
        method: POST
        body: user=YOUR_USER_KEY&priority=2&retry=60&expire=3600&sound=tugboat&title={{ .app.metadata.name | urlquery }}%20sync%20failed&message={{ if .app.status.operationState.message }}{{ .app.status.operationState.message | trunc 150 | urlquery }}{{ else }}Sync%20failed{{ end }}&url={{ .context.argocdUrl | urlquery }}%2Fapplications%2F{{ .app.metadata.name | urlquery }}

  template.app-health-degraded: |
    message: |
      ⚠️ *{{ .app.metadata.name }}*
      💔 Health degraded
      🏷 Namespace: `{{ .app.spec.destination.namespace }}`
      🔗 [Open in ArgoCD]({{ .context.argocdUrl }}/applications/{{ .app.metadata.name }})

  # Triggers with oncePer to prevent duplicate notifications
  trigger.on-sync-failed: |
    - description: Application syncing has failed
      oncePer: "[app.metadata.name, app.status.operationState?.syncResult?.revision]"
      send:
        - app-sync-failed
        - app-sync-failed-pushover
      when: app.status.operationState != nil and app.status.operationState.phase in ['Error', 'Failed']

  trigger.on-health-degraded: |
    - description: Application has degraded
      oncePer: app.status.operationState?.syncResult?.revision
      send:
        - app-health-degraded
      when: app.status.health.status == 'Degraded'

  # Subscriptions
  subscriptions: |
    # Critical: Telegram + Pushover
    - recipients:
        - telegram:-1001234567890|2
        - pushover-critical
      triggers:
        - on-sync-failed
    # Warning: Telegram only
    - recipients:
        - telegram:-1001234567890|5
      triggers:
        - on-health-degraded
```

**Note:** `telegram:-1001234567890|5` format:
- `-1001234567890` = chat_id
- `5` = message_thread_id (topic)

## Per-Application Subscriptions

Add annotations to specific apps:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: example-api-prd
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.telegram: "-1001234567890|5"
    notifications.argoproj.io/subscribe.on-sync-failed.telegram: "-1001234567890|2"
```

This sends:
- Deployed → Deploys topic (5)
- Sync failed → Critical topic (2)

## Trigger Reference

| Trigger | When |
|---------|------|
| `on-deployed` | Sync succeeded AND healthy |
| `on-sync-failed` | Sync error or failed |
| `on-health-degraded` | App health degraded |
| `on-sync-running` | Sync in progress |
| `on-sync-status-unknown` | Sync status unknown |
| `on-sync-succeeded` | Sync succeeded (any health) |

## Custom Trigger Example

Only notify on production apps:

```yaml
trigger.on-prd-deployed: |
  - when: app.status.operationState.phase in ['Succeeded'] and app.metadata.name =~ '.*-prd$'
    send: [app-deployed]
```

## Test Notifications

```bash
# Trigger manual notification
argocd app get example-api-prd --refresh

# Check notification controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller

# List notification subscriptions
kubectl get applications -A -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.annotations}' | grep notifications
```

## Troubleshooting

### Notifications not sending

1. Check controller logs:
   ```bash
   kubectl logs -n argocd deployment/argocd-notifications-controller
   ```

2. Verify secret exists:
   ```bash
   kubectl get secret argocd-notifications-secret -n argocd
   ```

3. Check ConfigMap:
   ```bash
   kubectl get configmap argocd-notifications-cm -n argocd -o yaml
   ```

### "Chat not found" error

- Verify chat_id format (negative for groups)
- Ensure bot is in the group
- Check topic ID is correct

### Template errors

Test template syntax:
```bash
argocd admin notifications template get app-deployed
```

## Pushover Integration

Pushover для критических алертов (обходит DND на iOS).

### Key Points

1. **Secret substitution** (`$secretKey`) работает только в `service.*` definitions, НЕ в template body
2. **Token в URL сервиса** - единственный способ передать token:
   ```yaml
   service.webhook.pushover-critical: |
     url: https://api.pushover.net/1/messages.json?token=$pushover-api-token
   ```
3. **Form-urlencoded** вместо JSON - избегает проблем с кавычками в error messages
4. **`urlquery` filter** - экранирует спецсимволы в template

### Pushover Priority Levels

| Priority | Behavior |
|----------|----------|
| -2 | Lowest (no notification) |
| -1 | Low (no sound) |
| 0 | Normal |
| 1 | High (bypass quiet hours) |
| 2 | Emergency (requires retry/expire, iOS Critical Alert) |

### Example Request

```
POST https://api.pushover.net/1/messages.json?token=xxx
Content-Type: application/x-www-form-urlencoded

user=xxx&priority=2&retry=60&expire=3600&title=app-name%20sync%20failed&message=Error%20message
```

## Notification Caching (oncePer)

ArgoCD предотвращает спам через `oncePer` - notification отправляется один раз пока значение не изменится.

### How it Works

```yaml
trigger.on-sync-failed: |
  - oncePer: "[app.metadata.name, app.status.operationState?.syncResult?.revision]"
```

- Кеш хранится в **Application annotations** (`notified.notifications.argoproj.io`)
- НЕ в памяти контроллера - рестарт не сбрасывает кеш
- Notification повторится только при новом revision (новый коммит)

### Clear Cache for Testing

```bash
# Удалить annotation чтобы notification отправился повторно
kubectl annotate app <app-name> -n argocd notified.notifications.argoproj.io-
```

### View Notification History

```bash
kubectl get app <app-name> -n argocd -o jsonpath='{.metadata.annotations.notified\.notifications\.argoproj\.io}' | jq .
```

## Integration with Alertmanager

ArgoCD notifications и Alertmanager работают параллельно:

| Source | Purpose | Topic |
|--------|---------|-------|
| Alertmanager | Infrastructure alerts | Critical/Warning/Info |
| ArgoCD | Deployment events | Deploys |

## Next Steps

→ [05-testing.md](05-testing.md) - Test alert delivery
