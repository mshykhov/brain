# Monitoring, Alerting & Disaster Recovery Research

> Research for bare-metal Kubernetes homelab
> Date: 2024-12

## Current Stack (Already Configured)

### kube-prometheus-stack ✅
- **Prometheus** — metrics, 15d retention, 20Gi storage (Longhorn)
- **Grafana** — dashboards, anonymous auth behind oauth2-proxy, 5Gi persistence
- **Alertmanager** — installed, 2Gi storage (needs routing config)
- **Node Exporter** — node metrics
- **kube-state-metrics** — kubernetes metrics
- **Loki datasource** — configured in Grafana (Loki not deployed yet)

**Chart version:** 79.10.0
**Location:** `example-infrastructure/apps/templates/monitoring/kube-prometheus-stack.yaml`
**Values:** `example-infrastructure/helm-values/monitoring/kube-prometheus-stack.yaml`

### Key Settings
```yaml
# Prometheus
retention: 15d
retentionSize: "10GB"
storage: 20Gi (Longhorn)

# Grafana
defaultDashboardsEnabled: true  # Built-in K8s dashboards
persistence: 5Gi (Longhorn)

# Auto-discovery
serviceMonitorSelectorNilUsesHelmValues: false  # Discover ALL ServiceMonitors
podMonitorSelectorNilUsesHelmValues: false      # Discover ALL PodMonitors
```

---

## What's Missing

| Component | Status | Priority |
|-----------|--------|----------|
| Alertmanager routing (Telegram/Discord) | ❌ Not configured | HIGH |
| CloudNativePG S3 backup (OVH) | ❌ Not configured | HIGH |
| Velero cluster backup | ❌ Not installed | MEDIUM |
| ArgoCD notifications | ❌ Not configured | MEDIUM |
| Loki (logs) | ❌ Not installed | LOW |
| Uptime Kuma | ❌ Optional | LOW |

---

## 1. Disaster Recovery

### What to Backup vs Recreate from Git

| Need Backup | Recreate from Git |
|-------------|-------------------|
| PostgreSQL data (CloudNativePG → S3) | Deployments, Services |
| PersistentVolumes (Velero) | ConfigMaps |
| Secrets (if not in Doppler) | Helm charts |

### Velero + MinIO

```bash
# Install MinIO (separate machine or in-cluster)
helm install minio minio/minio -n minio-system --create-namespace \
  --set persistence.size=100Gi

# Install Velero
helm install velero vmware-tanzu/velero -n velero --create-namespace \
  --set configuration.backupStorageLocation.bucket=velero-backups \
  --set configuration.backupStorageLocation.provider=aws \
  --set configuration.backupStorageLocation.config.s3Url=http://minio:9000

# Daily backup schedule
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --ttl 720h
```

### CloudNativePG S3 Backup (OVH)

```yaml
# Add to postgres cluster config
backup:
  barmanObjectStore:
    destinationPath: s3://postgres-backups/
    endpointURL: https://s3.gra.io.cloud.ovh.net
    s3Credentials:
      accessKeyId:
        name: ovh-s3-creds
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: ovh-s3-creds
        key: SECRET_ACCESS_KEY
    wal:
      compression: gzip
    retentionPolicy: "30d"
```

---

## 2. Alerting Configuration

### Alertmanager → Telegram

```yaml
# Add to kube-prometheus-stack values
alertmanager:
  config:
    global:
      resolve_timeout: 5m

    route:
      receiver: 'telegram'
      group_by: ['alertname', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h

      routes:
      - receiver: 'telegram-critical'
        matchers:
        - severity="critical"
      - receiver: 'telegram'
        matchers:
        - severity=~"warning|info"

    receivers:
    - name: 'telegram'
      telegram_configs:
      - bot_token: '<BOT_TOKEN>'
        chat_id: '<CHAT_ID>'
        message: |
          {{ range .Alerts }}
          {{ if eq .Status "firing" }}🔥{{ else }}✅{{ end }} {{ .Labels.alertname }}
          Severity: {{ .Labels.severity }}
          {{ .Annotations.summary }}
          {{ end }}

    - name: 'telegram-critical'
      telegram_configs:
      - bot_token: '<BOT_TOKEN>'
        chat_id: '<CHAT_ID>'
        message: |
          🚨 CRITICAL ALERT 🚨
          {{ range .Alerts }}
          {{ .Labels.alertname }}
          {{ .Annotations.description }}
          {{ end }}
```

### Key Alerts (built-in with kube-prometheus-stack)

| Alert | Description |
|-------|-------------|
| `Watchdog` | Always firing (proves alerting works) |
| `NodeNotReady` | Node down |
| `KubePodCrashLooping` | Pod restarting |
| `KubePersistentVolumeFillingUp` | Disk >85% |
| `PrometheusTargetMissing` | Scrape target down |

---

## 3. ArgoCD Notifications

```yaml
# argocd-notifications-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.telegram: |
    token: $telegram-token

  template.app-deployed: |
    message: |
      ✅ *{{ .app.metadata.name }}* deployed
      Revision: `{{ .app.status.sync.revision | trunc 7 }}`

  template.app-health-degraded: |
    message: |
      ⚠️ *{{ .app.metadata.name }}* health degraded
      Status: {{ .app.status.health.status }}

  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]
```

---

## 4. UI Dashboards

### Already Available
- **Grafana** — `https://grafana.<domain>` (behind oauth2-proxy)
  - Default dashboards enabled ✅
  - Kubernetes cluster overview
  - Node metrics
  - Pod metrics

- **ArgoCD UI** — deployment status, sync status, health

### Optional: Uptime Kuma (Simple Status Page)

```yaml
# Simple deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: uptime-kuma
spec:
  template:
    spec:
      containers:
      - name: uptime-kuma
        image: louislam/uptime-kuma:latest
        ports:
        - containerPort: 3001
```

---

## 5. Release Success Indicators

1. **ArgoCD UI** — Sync = "Synced", Health = "Healthy"
2. **Telegram notification** — "✅ example-api deployed"
3. **Grafana** — no error spikes, latency normal
4. **Health endpoint** — `/actuator/health` returns 200

---

## Implementation Priority

### Phase 1 (Critical)
1. [ ] Configure Alertmanager → Telegram
2. [ ] Setup CloudNativePG backup to OVH S3
3. [ ] Test alert delivery (Watchdog alert)

### Phase 2 (Important)
4. [ ] Install Velero + MinIO
5. [ ] Configure ArgoCD notifications
6. [ ] Test full DR scenario

### Phase 3 (Nice to have)
7. [ ] Deploy Loki for logs
8. [ ] Add custom Grafana dashboards
9. [ ] Uptime Kuma status page

---

## Official Sources

- Prometheus: https://prometheus.io/docs/
- Alertmanager: https://prometheus.io/docs/alerting/latest/configuration/
- Grafana: https://grafana.com/docs/grafana/latest/
- Velero: https://velero.io/docs/
- CloudNativePG Backup: https://cloudnative-pg.io/documentation/current/backup/
- ArgoCD Notifications: https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/
- Uptime Kuma: https://github.com/louislam/uptime-kuma
