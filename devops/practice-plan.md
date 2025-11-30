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

```bash
curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh | sudo bash
```

Дока: [docs/phase0/](docs/phase0/)

## Фаза 1: Core Infrastructure ✅
- [x] ArgoCD (ручная установка)
- [x] SSH ключ + Deploy key для example-infrastructure
- [x] Longhorn (wave 3)

Дока: [docs/phase1/](docs/phase1/)

| Компонент | Версия | Wave |
|-----------|--------|------|
| Longhorn | 1.10.1 | 3 |

> **Удалено:** MetalLB - не нужен с Tailscale + Cloudflare Tunnel

## Фаза 2: GitOps Structure ✅
- [x] Library Helm chart (`example-deploy/_library/`)
- [x] Helm chart для example-api (`example-deploy/services/example-api/`)
- [x] ApplicationSet для сервисов (Git Directory Generator)
- [x] SSH ключ для example-deploy в ArgoCD
- [x] Закоммитить и запушить example-deploy
- [x] Закоммитить и запушить example-infrastructure
- [x] Проверить что Application создался и синхронизировался

Дока: [docs/phase2/](docs/phase2/)

## Фаза 3: Secrets ✅
- [x] Doppler аккаунт (бесплатный Developer план)
- [x] Создать проект `example` и configs (`shared`, `dev`) в Doppler
- [x] External Secrets Operator 1.1.0 (через ArgoCD)
- [x] Doppler Service Tokens → K8s Secrets (`doppler-token-shared`, `doppler-token-dev`)
- [x] ClusterSecretStores (`doppler-shared`, `doppler-dev`)
- [x] ClusterExternalSecret для DockerHub credentials

Дока: [docs/phase3/](docs/phase3/)

| Компонент | Wave | Назначение |
|-----------|------|------------|
| External Secrets Operator | 4 | Синхронизация секретов |
| ClusterSecretStores | 5 | Подключение к Doppler |
| Docker Credentials | 6 | Pull из DockerHub |

## Фаза 4: CI/CD Automation ✅
- [x] Docker Hub Access Token (Read & Write) для GitHub Actions
- [x] GitHub Secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`
- [x] GitHub Actions workflow для example-api (build + push Docker image)
- [x] ArgoCD Image Updater (через GitOps, Helm chart v1.0.1)
- [x] ImageUpdater CRD (v1.0+ миграция с аннотаций)
- [x] Git write-back (коммиты в .argocd-source-*.yaml)
- [x] Тест: push tag → автодеплой (dev: ~0-0, prd: ~0)
- [x] HPA template (autoscaling/v2)
- [x] SecurityContext (runAsNonRoot, capabilities drop ALL)

Дока: [docs/phase4/](docs/phase4/)

| Компонент | Wave | Назначение |
|-----------|------|------------|
| ArgoCD Image Updater | 7 | Автообновление образов |
| ImageUpdater Config | 8 | CRD конфигурация |

## Фаза 5: Private Networking + Auth (ПЕРЕРАБОТАНО)

**Новая архитектура:**
- Tailscale VPN для internal сервисов (NO public URLs)
- NGINX Ingress Controller для routing + auth annotations
- oauth2-proxy + Auth0 для централизованной аутентификации
- Cloudflare Tunnel для public API (Фаза 6)

### 5.1 Tailscale Operator
- [ ] Tailscale OAuth client (Devices Core, Auth Keys, Services Write)
- [ ] Tailscale ACL configuration (tagOwners, grants)
- [ ] Doppler: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_CLIENT_SECRET`
- [ ] Tailscale Operator deployment (wave 9-10)
- [ ] Tailscale Service для NGINX Ingress (wave 11)

### 5.2 NGINX Ingress Controller
- [ ] NGINX Ingress Controller (ClusterIP, NOT LoadBalancer)
- [ ] Tailscale Service → NGINX Ingress (internal-ingress.tailnet.ts.net)

### 5.3 Auth0 Setup
- [ ] Auth0 аккаунт + tenant
- [ ] Auth0 Application (Regular Web App) для oauth2-proxy
- [ ] Auth0 Application (Regular Web App) для ArgoCD
- [ ] Auth0 Application (Regular Web App) для Grafana
- [ ] Auth0 API (для public example-api JWT validation)
- [ ] Auth0 Actions: Add groups to ID token
- [ ] Doppler: `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`

### 5.4 oauth2-proxy
- [ ] Doppler: `OAUTH2_PROXY_COOKIE_SECRET`
- [ ] Redis deployment (session storage)
- [ ] oauth2-proxy Helm chart deployment
- [ ] oauth2-proxy Ingress (auth.tailnet.ts.net)

### 5.5 Protected Services
- [ ] ArgoCD OIDC config (argocd-cm) → Auth0 direct
- [ ] ArgoCD Ingress (NGINX + oauth2-proxy protection)
- [ ] Longhorn Ingress (NGINX + oauth2-proxy protection)
- [ ] Grafana OIDC config (grafana.ini) → Auth0 direct
- [ ] Grafana Ingress (NGINX + oauth2-proxy protection)

Дока: [docs/phase5/](docs/phase5/)

| Компонент | Версия | Wave | Назначение |
|-----------|--------|------|------------|
| Tailscale Credentials | - | 9 | ExternalSecret для OAuth |
| Tailscale Operator | 1.90.9 | 10 | VPN + Service exposure |
| Tailscale Service (NGINX) | - | 11 | Expose NGINX to tailnet |
| NGINX Ingress Controller | 4.12.x | 12 | Internal routing + auth |
| Auth0 Credentials | - | 13 | ExternalSecret для Auth0 |
| Redis | 7.x | 14 | oauth2-proxy sessions |
| oauth2-proxy | 7.x | 15 | Auth middleware |
| ArgoCD OIDC Config | - | 16 | Auth0 integration |
| Protected Ingresses | - | 17 | ArgoCD, Longhorn, Grafana |

**Архитектура:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TAILSCALE VPN                                      │
│                                                                              │
│   Your Device (Tailscale Client)                                            │
│         │                                                                    │
│         ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐       │
│   │  Tailscale Service (LoadBalancer class: tailscale)              │       │
│   │  internal.tailnet-xxxx.ts.net                                   │       │
│   │                         │                                        │       │
│   │                         ▼                                        │       │
│   │  ┌───────────────────────────────────────────────────────┐      │       │
│   │  │  NGINX Ingress Controller (ClusterIP)                 │      │       │
│   │  │                                                        │      │       │
│   │  │  Ingress annotations:                                  │      │       │
│   │  │    auth-url: http://oauth2-proxy/oauth2/auth          │      │       │
│   │  │    auth-signin: https://auth.tailnet.ts.net/start     │      │       │
│   │  │                         │                              │      │       │
│   │  │                         ▼                              │      │       │
│   │  │  ┌─────────────────────────────────────────────┐      │      │       │
│   │  │  │  oauth2-proxy                                │      │      │       │
│   │  │  │  - provider: oidc (Auth0)                   │      │      │       │
│   │  │  │  - upstream: static://202                   │      │      │       │
│   │  │  │  - redis session store                      │      │      │       │
│   │  │  └─────────────────────────────────────────────┘      │      │       │
│   │  │                         │                              │      │       │
│   │  │              (authenticated)                           │      │       │
│   │  │                         ▼                              │      │       │
│   │  │  ┌─────────────────────────────────────────────┐      │      │       │
│   │  │  │  Backend Services                            │      │      │       │
│   │  │  │  - argocd.internal.ts.net → ArgoCD          │      │      │       │
│   │  │  │  - longhorn.internal.ts.net → Longhorn      │      │      │       │
│   │  │  │  - grafana.internal.ts.net → Grafana        │      │      │       │
│   │  │  └─────────────────────────────────────────────┘      │      │       │
│   │  └───────────────────────────────────────────────────────┘      │       │
│   └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Безопасность (3 уровня):**
1. **Network:** Tailscale VPN (только tailnet devices могут подключиться)
2. **Transport:** TLS/HTTPS (сертификаты от Tailscale)
3. **Application:** Auth0 OIDC через oauth2-proxy + NGINX

**Prerequisites:**
1. Tailscale account + OAuth client
2. Auth0 Free account (7,000 MAU)
3. Doppler secrets configured

**Удалено из старого плана:**
- ❌ MetalLB (не нужен)
- ❌ Traefik (заменён на NGINX)
- ❌ cert-manager (TLS от Tailscale для internal, от Cloudflare для public)
- ❌ ClusterIssuers (не нужны)

## Фаза 6: Public Access (Cloudflare Tunnel)

**После настройки private access добавляем public:**
- [ ] Cloudflare account + domain (~$10/year)
- [ ] Cloudflare Tunnel в Zero Trust Dashboard
- [ ] Doppler: `CF_TUNNEL_TOKEN`
- [ ] cloudflared deployment
- [ ] Public routes: api.example.com, app.example.com

Дока: [docs/phase6/](docs/phase6/)

| Компонент | Wave | Назначение |
|-----------|------|------------|
| Cloudflare Credentials | 20 | ExternalSecret для Tunnel |
| Cloudflare Tunnel | 21 | Public access без port forward |

**Архитектура:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                        │
│                                  │                                           │
│                    ┌─────────────▼─────────────┐                            │
│                    │     Cloudflare Edge       │                            │
│                    │  • DDoS Protection        │                            │
│                    │  • WAF                    │                            │
│                    │  • TLS Termination        │                            │
│                    └─────────────┬─────────────┘                            │
│                                  │                                           │
│                    ┌─────────────▼─────────────┐                            │
│                    │   Cloudflare Tunnel       │                            │
│                    │   (outbound only)         │                            │
│                    └─────────────┬─────────────┘                            │
│                                  │                                           │
│   ┌──────────────────────────────▼──────────────────────────────────────┐   │
│   │                         KUBERNETES                                   │   │
│   │                                                                      │   │
│   │   cloudflared pod                                                   │   │
│   │       │                                                              │   │
│   │       ├── api.example.com → example-api.prd:8080                    │   │
│   │       ├── api-dev.example.com → example-api.dev:8080                │   │
│   │       └── app.example.com → example-ui.prd:80                       │   │
│   │                                                                      │   │
│   │   Auth: JWT validation in Spring Boot (Auth0 tokens)                │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

**example-api JWT validation:**
```kotlin
// Spring Security Resource Server
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://YOUR_TENANT.auth0.com/
```

## Фаза 7: Data
- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster
- [ ] Credentials через ESO
- [ ] Подключить приложение к БД

## Фаза 8: Observability
- [ ] kube-prometheus-stack (Prometheus + Grafana)
- [ ] Loki + Promtail
- [ ] ServiceMonitor для приложения
- [ ] Grafana OIDC → Auth0
- [ ] Grafana Ingress (NGINX + oauth2-proxy)

## Фаза 9: Backup
- [ ] MinIO
- [ ] Velero
- [ ] Тест: backup → delete → restore

## Фаза 10: Full Test
- [ ] Все pods Running
- [ ] Private: ArgoCD, Longhorn, Grafana через VPN
- [ ] Public: example-api через Cloudflare
- [ ] Auth: Auth0 SSO работает везде
- [ ] CI/CD: push → autodeploy работает
- [ ] Метрики/логи работают
- [ ] Backup/restore работает

---

## Компоненты: Финальный Список

### Используем ✅
| Компонент | Назначение |
|-----------|------------|
| ArgoCD | GitOps |
| Longhorn | Storage |
| External Secrets + Doppler | Secrets management |
| ArgoCD Image Updater | Auto-update images |
| Tailscale Operator | VPN + Internal access |
| NGINX Ingress Controller | Internal routing + auth |
| oauth2-proxy | Auth middleware |
| Auth0 | Centralized OIDC |
| Redis | oauth2-proxy sessions |
| Cloudflare Tunnel | Public access |

### Удалено ❌
| Компонент | Причина |
|-----------|---------|
| MetalLB | Не нужен с Tailscale + Cloudflare |
| Traefik | Заменён на NGINX (лучше auth support) |
| cert-manager | TLS от Tailscale (internal) / Cloudflare (public) |
| ClusterIssuers | Не нужны без cert-manager |

---

## Sync Waves (Обновлённые)

| Wave | Component |
|------|-----------|
| 1-2 | (removed MetalLB) |
| 3 | Longhorn |
| 4 | External Secrets Operator |
| 5 | ClusterSecretStores |
| 6 | Docker Credentials |
| 7 | ArgoCD Image Updater |
| 8 | Image Updater Config |
| 9 | Tailscale Credentials |
| 10 | Tailscale Operator |
| 11 | Tailscale Service (NGINX) |
| 12 | NGINX Ingress Controller |
| 13 | Auth0 Credentials |
| 14 | Redis |
| 15 | oauth2-proxy |
| 16 | ArgoCD OIDC Config |
| 17 | Protected Ingresses |
| 20 | Cloudflare Credentials |
| 21 | Cloudflare Tunnel |
| 25 | Application Services |
