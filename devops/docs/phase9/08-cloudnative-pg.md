# CloudNativePG - PostgreSQL Operator

## Overview

CNCF Incubating project для Kubernetes-native PostgreSQL:
- Declarative cluster management через CRDs
- Automated failover и HA
- Rolling updates
- Integrated Prometheus monitoring

**Official docs:** https://cloudnative-pg.io/documentation/current/

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CloudNativePG Operator                        │
│                     (cnpg-system namespace)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
     ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
     │ example-api │  │ example-api │  │   other     │
     │ main-db-dev │  │ main-db-prd │  │  clusters   │
     └──────┬──────┘  └──────┬──────┘  └─────────────┘
            │                │
   ┌────────┴────────┐   ┌───┴───┐
   │ Pod (primary)   │   │ Pods  │
   │ + Secret        │   │ (HA)  │
   │ + Services      │   └───────┘
   └─────────────────┘
```

## Installation

ArgoCD Application: `apps/templates/core/cloudnative-pg.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudnative-pg
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  source:
    repoURL: https://cloudnative-pg.github.io/charts
    chart: cloudnative-pg
    targetRevision: "0.26.1"
```

## ApplicationSet

Matrix generator: environments × service configs

```yaml
# apps/templates/data/postgres-clusters.yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - env: dev
              - env: prd
        - git:
            files:
              - path: databases/*/postgres/*.yaml
```

**Naming:** `<service>-<db>-db-<env>` (e.g., `example-api-main-db-dev`)

## Value Precedence

1. `helm-values/data/postgres-<env>-defaults.yaml` (base)
2. `databases/<service>/postgres/<db>.yaml` (service config)
3. `databases/<service>/postgres/<db>-<env>.yaml` (optional env override)

## Environment Defaults

### DEV (`postgres-dev-defaults.yaml`)

```yaml
version:
  postgresql: "17"

cluster:
  instances: 1
  storage:
    storageClass: longhorn
  resources:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }
  monitoring:
    enabled: true
    podMonitor:
      enabled: true
```

### PRD (`postgres-prd-defaults.yaml`)

```yaml
version:
  postgresql: "17"

cluster:
  instances: 1  # increase for HA
  storage:
    storageClass: longhorn
  resources:
    requests: { cpu: 250m, memory: 512Mi }
    limits: { cpu: "1", memory: 1Gi }
  monitoring:
    enabled: true
    podMonitor:
      enabled: true
    prometheusRule:
      enabled: true
  affinity:
    topologyKey: kubernetes.io/hostname
```

## Service Config Example

```yaml
# deploy: databases/example-api/postgres/main.yaml
cluster:
  instances: 1
  storage:
    size: 10Gi
  initdb:
    database: example_api
    owner: example_api
```

## Generated Resources

CloudNativePG автоматически создаёт:

### Secret (`<cluster>-app`)

| Key | Description |
|-----|-------------|
| `username` | App user |
| `password` | Password |
| `host` | Service host |
| `port` | 5432 |
| `dbname` | Database name |
| `uri` | `postgresql://user:pass@host:5432/db` |
| `jdbc-uri` | `jdbc:postgresql://host:5432/db` |

### Services

| Service | Purpose |
|---------|---------|
| `<cluster>-rw` | Primary (read/write) |
| `<cluster>-ro` | Replicas only (read-only) |
| `<cluster>-r` | Any instance (read) |

## Connection Example

```yaml
# deploy: services/example-api/values.yaml
extraEnv:
  - name: SPRING_DATASOURCE_URL
    valueFrom:
      secretKeyRef:
        name: example-api-main-db-dev-app
        key: jdbc-uri
  - name: SPRING_DATASOURCE_USERNAME
    valueFrom:
      secretKeyRef:
        name: example-api-main-db-dev-app
        key: username
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: example-api-main-db-dev-app
        key: password
```

## Available Options

```yaml
# Type
type: postgresql | postgis | timescaledb

# Version
version:
  postgresql: "17"
  postgis: "3.4"
  timescaledb: "2.15"

# Cluster
cluster:
  instances: 3
  storage:
    size: 10Gi
    storageClass: longhorn
  walStorage:
    enabled: true
    size: 2Gi
  initdb:
    database: mydb
    owner: myuser
    postInitSQL:
      - CREATE EXTENSION IF NOT EXISTS vector;
  postgresql:
    parameters:
      max_connections: "300"
      shared_buffers: "256MB"
```

## Verify

```bash
# Check clusters
kubectl get clusters -A

# Check pods
kubectl get pods -n example-api-dev -l cnpg.io/cluster=example-api-main-db-dev

# Check secret
kubectl get secret example-api-main-db-dev-app -n example-api-dev -o yaml

# Connect
kubectl exec -n example-api-dev -it example-api-main-db-dev-1 -- psql
```

## vs Bitnami PostgreSQL

| Aspect | CloudNativePG | Bitnami |
|--------|---------------|---------|
| Type | Operator + CRD | Helm Chart |
| HA | Built-in failover | Requires setup |
| Secrets | Auto-generated | Manual or lookup |
| Upgrades | Rolling updates | Recreate |
| Monitoring | Native PodMonitor | External |
