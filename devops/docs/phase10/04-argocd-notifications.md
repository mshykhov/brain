# ArgoCD Notifications

## Overview

ArgoCD has built-in notifications controller. Send deployment events to Telegram.

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
```

### Step 2: ConfigMap

```yaml
# manifests/argocd-config/argocd-notifications-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Telegram service
  service.telegram: |
    token: $telegram-token

  # Templates
  template.app-deployed: |
    message: |
      ✅ <b>Deployed</b>: {{ .app.metadata.name }}
      <b>Revision:</b> <code>{{ .app.status.sync.revision | trunc 7 }}</code>
      <b>Namespace:</b> {{ .app.spec.destination.namespace }}

  template.app-sync-failed: |
    message: |
      ❌ <b>Sync Failed</b>: {{ .app.metadata.name }}
      <b>Error:</b> {{ .app.status.operationState.message }}

  template.app-health-degraded: |
    message: |
      ⚠️ <b>Degraded</b>: {{ .app.metadata.name }}
      <b>Status:</b> {{ .app.status.health.status }}

  template.app-sync-running: |
    message: |
      🔄 <b>Syncing</b>: {{ .app.metadata.name }}
      <b>Revision:</b> <code>{{ .app.status.sync.revision | trunc 7 }}</code>

  # Triggers
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      send: [app-deployed]

  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]

  trigger.on-sync-running: |
    - when: app.status.operationState.phase in ['Running']
      send: [app-sync-running]

  # Default subscriptions (all apps)
  subscriptions: |
    - recipients:
        - telegram:-1001234567890|5
      triggers:
        - on-deployed
        - on-sync-failed
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

## Integration with Alertmanager

ArgoCD notifications и Alertmanager работают параллельно:

| Source | Purpose | Topic |
|--------|---------|-------|
| Alertmanager | Infrastructure alerts | Critical/Warning/Info |
| ArgoCD | Deployment events | Deploys |

## Next Steps

→ [05-testing.md](05-testing.md) - Test alert delivery
