# План практики GitOps Infrastructure

> **Принцип:** Всё управляется через GitOps. Вручную устанавливается ТОЛЬКО ArgoCD.

## Фаза 0: Подготовка ✅
- [x] VM (4 CPU, 8GB RAM, Ubuntu 22.04+)
- [x] k3s без traefik и servicelb
- [x] kubectl, helm, k9s
- [x] Tailscale SSH
- [x] GitHub репо: `example-infrastructure`
- [x] GitHub репо: `example-deploy`
- [x] GitHub репо: `example-api` (Kotlin/Spring Boot)

Дока: [docs/phase0/](docs/phase0/)

## Фаза 1: Core Infrastructure ✅
- [x] ArgoCD (ручная установка)
- [x] SSH ключ + Deploy key для example-infrastructure
- [x] Longhorn (wave 3)

Дока: [docs/phase1/](docs/phase1/)

## Фаза 2: GitOps Structure ✅
- [x] Library Helm chart (`example-deploy/_library/`)
- [x] Helm chart для example-api (`example-deploy/services/example-api/`)
- [x] ApplicationSet для сервисов (Git Directory Generator)
- [x] SSH ключ для example-deploy в ArgoCD

Дока: [docs/phase2/](docs/phase2/)

## Фаза 3: Secrets ✅
- [x] Doppler аккаунт
- [x] External Secrets Operator (wave 4)
- [x] ClusterSecretStores (`doppler-shared`, `doppler-dev`, `doppler-prd`)
- [x] ClusterExternalSecret для DockerHub credentials

Дока: [docs/phase3/](docs/phase3/)

## Фаза 4: CI/CD Automation ✅
- [x] GitHub Actions workflow для example-api
- [x] ArgoCD Image Updater с ImageUpdater CRD (v1.0+)
- [x] Git write-back (коммиты в .argocd-source-*.yaml)
- [x] Semver constraints: ~0-0 (dev), ~0 (prd)

Дока: [docs/phase4/](docs/phase4/)

## Фаза 5: Private Networking + Auth ✅

**Архитектура:**
```
User → Tailscale VPN → Tailscale Ingress → NGINX → oauth2-proxy → Backend
```

### Компоненты
- [x] Tailscale Operator (wave 10) — VPN + Service exposure
- [x] NGINX Ingress Controller (wave 12) — Internal routing
- [x] Auth0 OIDC — Centralized authentication
- [x] Auth0 Action — Groups claim (`https://ns/groups`)
- [x] oauth2-proxy (wave 15) — Auth middleware + Redis HA
- [x] ArgoCD anonymous mode — За oauth2-proxy
- [x] Protected Services chart (wave 17) — Dynamic ingresses
- [x] Credentials chart — Centralized ExternalSecrets

### Key Decisions
| Решение | Почему |
|---------|--------|
| Anonymous ArgoCD | Проще чем OIDC + oauth2-proxy dual auth |
| Redis HA | Production session storage |
| Namespaced groups claim | Auth0 requirement |
| Separate Tailscale Ingress per service | Simpler callback URLs |

Дока: [docs/phase5/](docs/phase5/)

| Компонент | Wave | Версия |
|-----------|------|--------|
| Credentials | 5 | - |
| Tailscale Operator | 10 | 1.90.9 |
| NGINX Ingress | 12 | 4.12.x |
| oauth2-proxy | 15 | 9.0.0 |
| Protected Services | 17 | - |

## Фаза 6: Public Access (Cloudflare Tunnel)

**Статус:** GitOps ready, waiting for Cloudflare setup

### 6.1 Cloudflare Setup
- [ ] Cloudflare account (free)
- [ ] Domain (~$10/year via Cloudflare Registrar)
- [ ] Tunnel created in Zero Trust Dashboard

### 6.2 Secrets
- [ ] Doppler shared: `CF_TUNNEL_TOKEN`

### 6.3 Kubernetes (GitOps ready ✅)
- [x] ExternalSecret: `charts/credentials/templates/cloudflare.yaml`
- [x] Helm chart: `charts/cloudflare-tunnel/`
- [x] ArgoCD Application: `apps/templates/network/cloudflare-tunnel.yaml`

### 6.4 Public Hostnames (Cloudflare Dashboard)
- [ ] api.domain.com → example-api.prd:8080
- [ ] app.domain.com → example-ui.prd:80 (future)

> **Note:** DEV остаётся private (только через Tailscale VPN)

| Компонент | Wave |
|-----------|------|
| Cloudflare Credentials | 20 |
| Cloudflare Tunnel | 21 |

Дока: [docs/phase6/](docs/phase6/)

## Фаза 7: Data

- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster
- [ ] Credentials через ESO
- [ ] Подключить приложение к БД

## Фаза 8: Observability

- [ ] kube-prometheus-stack
- [ ] Loki + Promtail
- [ ] Grafana OIDC (через oauth2-proxy)
- [ ] ServiceMonitor для приложения

## Фаза 9: Backup

- [ ] MinIO
- [ ] Velero
- [ ] Тест: backup → delete → restore

---

## Sync Waves

| Wave | Component |
|------|-----------|
| 2 | ArgoCD Config |
| 3 | Longhorn |
| 4 | External Secrets Operator |
| 5 | ClusterSecretStores + Credentials |
| 7 | ArgoCD Image Updater |
| 8 | Image Updater Config |
| 10 | Tailscale Operator |
| 12 | NGINX Ingress Controller |
| 15 | oauth2-proxy |
| 17 | Protected Services |
| 20+ | Cloudflare (future) |
| 25 | Application Services |

---

## Doppler Secrets

### shared config
| Key | Описание |
|-----|----------|
| `DOCKERHUB_PULL_TOKEN` | DockerHub Access Token |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth |
| `AUTH0_CLIENT_SECRET` | Auth0 Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | Cookie encryption |
| `OAUTH2_PROXY_REDIS_PASSWORD` | Redis password |

### apps/values.yaml (non-secrets)
| Key | Описание |
|-----|----------|
| `global.tailnet` | Tailscale tailnet name |
| `global.tailscale.clientId` | Tailscale OAuth Client ID |
| `global.auth0.domain` | Auth0 domain |
| `global.auth0.clientId` | Auth0 Client ID |
| `global.dockerhub.username` | DockerHub username |
