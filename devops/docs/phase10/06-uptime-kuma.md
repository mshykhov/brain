# Uptime Kuma

## Overview

Lightweight status page и uptime monitoring. Быстрый взгляд "всё ли работает?" без навигации по Grafana dashboards.

**Why Uptime Kuma + Grafana:**

| Uptime Kuma | Grafana |
|-------------|---------|
| Open → сразу видно что up/down | Нужно открывать dashboards |
| Traffic light UI (green/red) | Графики требуют интерпретации |
| 5 минут на setup | Нужно строить dashboards |
| Status page для sharing | Нет built-in status page |
| ~100MB RAM | Heavier |

**Use case:** Uptime Kuma для quick glance, Grafana для deep analysis.

## Installation

### ArgoCD Application

```yaml
# apps/templates/monitoring/uptime-kuma.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: uptime-kuma
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "15"
spec:
  project: default
  source:
    repoURL: https://helm.irsigler.cloud
    chart: uptime-kuma
    targetRevision: "2.20.0"
    helm:
      valueFiles:
        - /helm-values/monitoring/uptime-kuma.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Helm Values

```yaml
# helm-values/monitoring/uptime-kuma.yaml
image:
  tag: "1"  # Latest stable

persistence:
  enabled: true
  storageClass: longhorn
  size: 2Gi

resources:
  requests:
    cpu: 50m
    memory: 100Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Ingress via protected-services chart
ingress:
  enabled: false
```

### Add to Protected Services (Internal Access)

```yaml
# charts/protected-services/values.yaml
services:
  uptime-kuma:
    enabled: true
    hostname: uptime.tail876052.ts.net
    namespace: monitoring
    backend:
      name: uptime-kuma
      port: 3001
    oauth2: true  # Behind oauth2-proxy
```

## Configuration

### After Deployment

1. Open `https://uptime.tail876052.ts.net`
2. Create admin account
3. Add monitors:

### Recommended Monitors

| Monitor | Type | URL/Host | Interval |
|---------|------|----------|----------|
| example-api-dev | HTTP | http://example-api.example-api-dev.svc:8080/actuator/health | 60s |
| example-api-prd | HTTP | http://example-api.example-api-prd.svc:8080/actuator/health | 60s |
| example-ui-dev | HTTP | http://example-ui.example-ui-dev.svc:80 | 60s |
| example-ui-prd | HTTP | http://example-ui.example-ui-prd.svc:80 | 60s |
| PostgreSQL dev | TCP | example-api-main-db-dev-rw.example-api-dev:5432 | 60s |
| PostgreSQL prd | TCP | example-api-main-db-prd-rw.example-api-prd:5432 | 60s |
| Redis dev | TCP | redis-dev.example-api-dev:6379 | 60s |
| Redis prd | TCP | redis-prd-master.example-api-prd:6379 | 60s |
| ArgoCD | HTTP | http://argocd-server.argocd.svc:80/healthz | 60s |
| Grafana | HTTP | http://kube-prometheus-stack-grafana.monitoring.svc:80/api/health | 60s |
| Prometheus | HTTP | http://prometheus-operated.monitoring.svc:9090/-/healthy | 60s |

### External Monitors (PRD)

| Monitor | Type | URL | Interval |
|---------|------|-----|----------|
| untrustedonline.org | HTTP | https://untrustedonline.org | 60s |
| api.untrustedonline.org | HTTP | https://api.untrustedonline.org/actuator/health | 60s |

## Telegram Notifications

Uptime Kuma has built-in Telegram integration:

1. Settings → Notifications → Setup Notification
2. Type: Telegram
3. Bot Token: (same as Alertmanager)
4. Chat ID: (use Info topic ID with format `chat_id/topic_id`)

**Format:** `-1001234567890/4` (chat_id/message_thread_id)

## Status Page

Create public/private status page:

1. Status Pages → Add Status Page
2. Add monitors to groups:
   - **Production**: example-api-prd, example-ui-prd, external URLs
   - **Development**: example-api-dev, example-ui-dev
   - **Infrastructure**: PostgreSQL, Redis, ArgoCD, Grafana

## Prometheus Metrics

Uptime Kuma exposes Prometheus metrics:

```yaml
# Add ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: uptime-kuma
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: uptime-kuma
  endpoints:
    - port: http
      path: /metrics
      interval: 60s
```

Grafana dashboard: https://grafana.com/grafana/dashboards/18278-uptime-kuma/

## Backup

Data stored in SQLite at `/app/data/kuma.db`.

Longhorn snapshot covers this automatically.

Manual backup:
```bash
kubectl exec -n monitoring deploy/uptime-kuma -- cat /app/data/kuma.db > kuma-backup.db
```

## vs Blackbox Exporter

| Uptime Kuma | Blackbox Exporter |
|-------------|-------------------|
| UI + Status Page | Prometheus metrics only |
| Built-in notifications | Needs Alertmanager |
| Easy setup | Requires config |
| SQLite storage | Stateless |

**Recommendation:** Use both - Uptime Kuma for quick status, Blackbox for Prometheus/Grafana integration.

## Troubleshooting

```bash
# Check pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=uptime-kuma

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=uptime-kuma

# Check persistence
kubectl get pvc -n monitoring | grep uptime
```
