# Alertmanager Configuration

## Overview

Alertmanager config в kube-prometheus-stack Helm values.

**Location:** `helm-values/monitoring/kube-prometheus-stack.yaml`

## Full Configuration

```yaml
alertmanager:
  enabled: true

  # Storage for silences and notifications
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          resources:
            requests:
              storage: 2Gi

  # Main configuration
  config:
    global:
      resolve_timeout: 5m
      telegram_api_url: "https://api.telegram.org"

    # Routing tree
    route:
      receiver: 'telegram-info'
      group_by: ['alertname', 'severity', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h

      routes:
        # Critical → immediate notification
        - receiver: 'telegram-critical'
          matchers:
            - severity="critical"
          repeat_interval: 1h
          continue: false

        # Warning → less urgent
        - receiver: 'telegram-warning'
          matchers:
            - severity="warning"
          repeat_interval: 4h
          continue: false

        # Watchdog → info (proves alerting works)
        - receiver: 'telegram-info'
          matchers:
            - alertname="Watchdog"
          repeat_interval: 24h
          continue: false

        # Everything else → info
        - receiver: 'telegram-info'

    # Suppress redundant alerts
    inhibit_rules:
      # Critical suppresses Warning for same alert
      - source_matchers:
          - severity="critical"
        target_matchers:
          - severity="warning"
        equal: ['alertname', 'namespace']

      # Node down suppresses all alerts from that node
      - source_matchers:
          - alertname="KubeNodeNotReady"
        target_matchers:
          - severity=~"warning|info"
        equal: ['node']

      # Cluster unreachable suppresses member alerts
      - source_matchers:
          - alertname="KubeControllerManagerDown"
        target_matchers:
          - alertname=~"Kube.*"

    # Receivers
    receivers:
      - name: 'telegram-critical'
        telegram_configs:
          - bot_token_file: /etc/alertmanager/secrets/telegram-secrets/bot-token
            chat_id: -1001234567890  # Replace with your CHAT_ID
            message_thread_id: 2      # Replace with TOPIC_CRITICAL
            parse_mode: 'HTML'
            send_resolved: true
            message: |-
              {{ if eq .Status "firing" }}🚨 <b>CRITICAL</b>{{ else }}✅ <b>RESOLVED</b>{{ end }}

              <b>Alert:</b> {{ .GroupLabels.alertname }}
              <b>Namespace:</b> {{ .GroupLabels.namespace | default "cluster" }}

              {{ range .Alerts }}
              <b>Description:</b> {{ .Annotations.description | default .Annotations.summary }}
              {{ if .Annotations.runbook_url }}<a href="{{ .Annotations.runbook_url }}">Runbook</a>{{ end }}
              {{ end }}

      - name: 'telegram-warning'
        telegram_configs:
          - bot_token_file: /etc/alertmanager/secrets/telegram-secrets/bot-token
            chat_id: -1001234567890
            message_thread_id: 3      # Replace with TOPIC_WARNING
            parse_mode: 'HTML'
            send_resolved: true
            message: |-
              {{ if eq .Status "firing" }}⚠️ <b>WARNING</b>{{ else }}✅ <b>RESOLVED</b>{{ end }}

              <b>Alert:</b> {{ .GroupLabels.alertname }}
              {{ range .Alerts }}
              {{ .Annotations.summary }}
              {{ end }}

      - name: 'telegram-info'
        telegram_configs:
          - bot_token_file: /etc/alertmanager/secrets/telegram-secrets/bot-token
            chat_id: -1001234567890
            message_thread_id: 4      # Replace with TOPIC_INFO
            parse_mode: 'HTML'
            send_resolved: true
            message: |-
              {{ if eq .Status "firing" }}ℹ️{{ else }}✅{{ end }} {{ .GroupLabels.alertname }}
              {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}

  # Mount secrets
  alertmanagerSpec:
    secrets:
      - telegram-secrets
```

## ExternalSecret for Telegram

Create ExternalSecret to sync bot token from Doppler:

```yaml
# charts/credentials/templates/telegram.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: telegram-secrets
  namespace: monitoring
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: telegram-secrets
    creationPolicy: Owner
  data:
    - secretKey: bot-token
      remoteRef:
        key: TELEGRAM_BOT_TOKEN
```

## Timing Parameters

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `group_wait` | 30s | Wait before sending first notification |
| `group_interval` | 5m | Wait before sending updates to group |
| `repeat_interval` | 4h | Re-send if alert still firing |
| `resolve_timeout` | 5m | Mark resolved if no update |

## Routing Logic

```
Alert arrives
    │
    ├── severity=critical? → telegram-critical (repeat: 1h)
    │
    ├── severity=warning? → telegram-warning (repeat: 4h)
    │
    ├── alertname=Watchdog? → telegram-info (repeat: 24h)
    │
    └── else → telegram-info (default)
```

## Inhibit Rules Explained

### 1. Critical suppresses Warning

```yaml
- source_matchers:
    - severity="critical"
  target_matchers:
    - severity="warning"
  equal: ['alertname', 'namespace']
```

If `KubePodCrashLooping` fires as critical AND warning, only critical notification sent.

### 2. Node down suppresses related

```yaml
- source_matchers:
    - alertname="KubeNodeNotReady"
  target_matchers:
    - severity=~"warning|info"
  equal: ['node']
```

If node is down, don't spam about pods on that node.

## HTML vs MarkdownV2

Use `parse_mode: 'HTML'` because:
- More predictable escaping
- MarkdownV2 requires escaping: `_*[]()~>#+-=|{}.!`
- HTML tags: `<b>`, `<i>`, `<a href="">`, `<code>`

## Verify Configuration

```bash
# Check Alertmanager config
kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Check Alertmanager status
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# Open http://localhost:9093/#/status
```

## Next Steps

→ [03-builtin-alerts.md](03-builtin-alerts.md) - Important built-in alerts
