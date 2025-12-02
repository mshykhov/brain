# Loki - Log Aggregation

## Overview

Loki - система агрегации логов от Grafana. Оптимизирована для Kubernetes.

**Режимы деплоя:**
- **Monolithic/SingleBinary** - все компоненты в одном процессе (для small deployments)
- **Simple Scalable** - read/write separation
- **Microservices** - full horizontal scaling

Для single-node k3s используем **SingleBinary**.

## Installation

### ArgoCD Application

```yaml
# apps/templates/monitoring/loki.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: loki
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "32"
spec:
  sources:
    - repoURL: https://grafana.github.io/helm-charts
      chart: loki
      targetRevision: "6.46.0"
      helm:
        valueFiles:
          - $values/helm-values/monitoring/loki.yaml
    - repoURL: <infrastructure-repo>
      ref: values
  destination:
    namespace: monitoring
```

## Key Configuration

### SingleBinary Mode

```yaml
# helm-values/monitoring/loki.yaml
deploymentMode: SingleBinary

loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem

singleBinary:
  replicas: 1
  persistence:
    enabled: true
    storageClass: longhorn
    size: 10Gi
```

### Schema v13 (TSDB)

```yaml
loki:
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
```

### Retention

```yaml
loki:
  limits_config:
    retention_period: 168h  # 7 days
```

### Disable Unused Components

```yaml
# Disable scalable components (not needed in SingleBinary)
backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0
gateway:
  enabled: false
minio:
  enabled: false
```

## Endpoint

```
http://loki.monitoring.svc.cluster.local:3100
```

## Official Docs

- https://grafana.com/docs/loki/latest/setup/install/helm/
- https://grafana.com/docs/loki/latest/get-started/deployment-modes/
