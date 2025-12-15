# Decentralized Ingress & Tailscale Configuration

## Overview

Конфигурация ingress и Tailscale находится в deploy репозитории рядом с сервисами и базами данных.

```
deploy/services/*/values-{env}.yaml     → ingress для сервисов
deploy/databases/*/postgres/main.yaml   → tailscale для БД
infrastructure/charts/protected-services → только infra сервисы (vault, argocd, grafana, longhorn)
```

## Архитектура

### Services (HTTP)

```
deploy/services/blackpoint-api/values-dev.yaml
  └── ingress.enabled: true
        │
        ▼
ApplicationSet (services)
  └── sources:
        ├── Service Helm chart (Deployment, Service)
        └── service-ingress chart (NGINX + Tailscale Ingress)
              │
              ▼
        DEV: blackpoint-api-dev.trout-paradise.ts.net
        PRD: api-blackpoint.gaynance.com
```

### Databases (TCP)

```
deploy/databases/blackpoint-api/postgres/main.yaml
  └── tailscale.enabled: true
        │
        ▼
ApplicationSet (postgres-clusters)
  └── sources:
        ├── CloudNativePG Cluster chart
        └── tailscale-service chart (LoadBalancer)
              │
              ▼
        blackpoint-db-dev.trout-paradise.ts.net:5432
```

## Конфигурация

### Service DEV (Tailscale)

```yaml
# deploy/services/blackpoint-api/values-dev.yaml
ingress:
  enabled: true
  tailscale:
    enabled: true
```

### Service PRD (Cloudflare)

```yaml
# deploy/services/blackpoint-api/values-prd.yaml
ingress:
  enabled: true
  subdomain: api-blackpoint  # => api-blackpoint.gaynance.com
```

### Database

```yaml
# deploy/databases/blackpoint-api/postgres/main.yaml
cluster:
  instances: 1
  storage:
    size: 5Gi
  initdb:
    database: blackpoint
    owner: blackpoint

tailscale:
  enabled: true
  hostname: blackpoint-db  # => blackpoint-db-{env}.ts.net:5432
```

## Protected Services

Только infrastructure сервисы:

| Service | Access |
|---------|--------|
| vault | vault.ts.net (direct) |
| argocd | argocd.ts.net |
| longhorn | longhorn.ts.net |
| grafana | grafana.ts.net |

## Endpoints

| Service | DEV | PRD |
|---------|-----|-----|
| blackpoint-api | blackpoint-api-dev.ts.net | api-blackpoint.gaynance.com |
| blackpoint-ui | blackpoint-ui-dev.ts.net | blackpoint.gaynance.com |
| blackpoint-db | blackpoint-db-dev.ts.net:5432 | blackpoint-db-prd.ts.net:5432 |
| notifier-db | notifier-db-dev.ts.net:5432 | notifier-db-prd.ts.net:5432 |

## Files

| File | Purpose |
|------|---------|
| `infrastructure/charts/service-ingress/` | HTTP ingress chart |
| `infrastructure/charts/tailscale-service/` | TCP LoadBalancer chart |
| `infrastructure/charts/protected-services/` | Infra services only |
| `deploy/services/*/values-{env}.yaml` | Service ingress config |
| `deploy/databases/*/postgres/main.yaml` | Database tailscale config |
