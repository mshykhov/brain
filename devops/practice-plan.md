# План практики GitOps Infrastructure

> **Принцип:** Всё управляется через GitOps. Вручную устанавливается ТОЛЬКО ArgoCD.

## Фаза 0: Подготовка
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

## Фаза 1: Core Infrastructure
- [x] ArgoCD (ручная установка)
- [x] SSH ключ + Deploy key для example-infrastructure
- [x] MetalLB (wave 1-2)
- [x] Longhorn (wave 3)

Дока: [docs/phase1/](docs/phase1/)

| Компонент | Версия | Wave |
|-----------|--------|------|
| MetalLB | 0.15.2 | 1 |
| MetalLB Config | - | 2 |
| Longhorn | 1.10.1 | 3 |

## Фаза 2: GitOps Structure ✅
- [x] Library Helm chart (`example-deploy/_library/`)
- [x] Helm chart для example-api (`example-deploy/services/example-api/`)
- [x] ApplicationSet для сервисов (Git Directory Generator)
- [x] SSH ключ для example-deploy в ArgoCD
- [x] Закоммитить и запушить example-deploy
- [x] Закоммитить и запушить example-infrastructure
- [x] Проверить что Application создался и синхронизировался

Дока: [docs/phase2/](docs/phase2/)

> **Примечание:** Pod в статусе `ImagePullBackOff` — это ожидаемо! Docker образ ещё не существует и credentials не настроены. Исправим в Фазе 3-4.

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

## Фаза 5: Networking ✅
- [x] Tailscale Operator (wave 9-10) — kubectl через Tailscale
- [x] Tailscale Ingress для ArgoCD (wave 11) — built-in OIDC
- [ ] Traefik Ingress Controller (wave 12) — public + internal via Tailscale LB
- [ ] cert-manager (wave 13) — только для public сервисов

Дока: [docs/phase5/](docs/phase5/)

| Компонент | Версия | Wave | Назначение |
|-----------|--------|------|------------|
| Tailscale Credentials | - | 9 | ExternalSecret для OAuth |
| Tailscale Operator | 1.90.9 | 10 | API Server Proxy (kubectl) |
| Tailscale Ingress (ArgoCD) | - | 11 | ArgoCD UI (has built-in OIDC) |
| Traefik | TBD | 12 | Ingress Controller (public + internal) |
| cert-manager | TBD | 13 | TLS для public сервисов |

**Tailscale Prerequisites (выполнено):**
1. ✅ ACL: `tagOwners`, `acls`, `grants`, `ssh` секции
2. ✅ OAuth client (Devices Core, Auth Keys, Services Write)
3. ✅ HTTPS Certificates и MagicDNS enabled
4. ✅ Doppler: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_CLIENT_SECRET`

**Важно:** ACL должен содержать `acls` секцию, иначе потеряется SSH доступ!

**Access (работает):**
- `tailscale configure kubeconfig tailscale-operator` → kubectl
- https://argocd.tail876052.ts.net (ArgoCD UI)

**Traefik архитектура:**
```
┌─────────────────────────────────────────────────────────────────┐
│                         TAILNET (private)                       │
│                                                                 │
│   Traefik Service (loadBalancerClass: tailscale)               │
│   traefik.tail876052.ts.net                                    │
│   ├── TLS: certificateResolver: tailscale (auto Let's Encrypt) │
│   ├── Middleware: ForwardAuth → oauth2-proxy → Auth0           │
│   └── Routes:                                                  │
│       ├── longhorn.ts.net → Longhorn UI                        │
│       ├── prometheus.ts.net → Prometheus                       │
│       └── alertmanager.ts.net → AlertManager                   │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET (public)                       │
│                                                                 │
│   Traefik Service (type: LoadBalancer via MetalLB)             │
│   ├── TLS: cert-manager + Let's Encrypt                        │
│   ├── Middleware: ForwardAuth → oauth2-proxy → Auth0 (web UI)  │
│   ├── JWT validation (API endpoints)                           │
│   └── Routes:                                                  │
│       └── api.example.com → example-api                        │
└─────────────────────────────────────────────────────────────────┘
```

**TLS стратегия:**
| Network | TLS Provider | Как |
|---------|--------------|-----|
| Tailscale (internal) | Traefik + Tailscale cert resolver | Автоматически от Tailscale |
| Public (internet) | Traefik + cert-manager | Let's Encrypt ACME |

Docs:
- https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/tailscale/
- https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress

## Фаза 6: Centralized Auth (Auth0)
- [ ] Auth0 аккаунт + tenant
- [ ] Auth0 Application (Regular Web App) для oauth2-proxy
- [ ] Auth0 Application для ArgoCD (built-in OIDC)
- [ ] Auth0 API для example-api (JWT validation)
- [ ] oauth2-proxy deployment (Helm chart)
- [ ] Traefik ForwardAuth middleware → oauth2-proxy
- [ ] ArgoCD OIDC config
- [ ] Grafana generic_oauth config
- [ ] example-api: JWT validation в Spring Security
- [ ] RBAC через Auth0 roles/permissions

Дока: [docs/phase6/](docs/phase6/)

| Компонент | Встроенный OIDC? | Auth метод | Network |
|-----------|------------------|------------|---------|
| ArgoCD | ✅ | Built-in OIDC → Auth0 | Tailscale Ingress |
| Grafana | ✅ | `[auth.generic_oauth]` → Auth0 | Traefik (Tailscale LB) |
| Longhorn | ❌ | Traefik ForwardAuth → oauth2-proxy → Auth0 | Traefik (Tailscale LB) |
| Prometheus | ❌ | Traefik ForwardAuth → oauth2-proxy → Auth0 | Traefik (Tailscale LB) |
| AlertManager | ❌ | Traefik ForwardAuth → oauth2-proxy → Auth0 | Traefik (Tailscale LB) |
| example-api (web) | - | Traefik ForwardAuth → oauth2-proxy → Auth0 | Traefik (Public LB) |
| example-api (API) | - | JWT verification (Spring Security) | Traefik (Public LB) |

**Архитектура oauth2-proxy:**
```
User Request → Traefik
                 │
                 ▼ ForwardAuth
         ┌───────────────┐
         │ oauth2-proxy  │◄──► Auth0
         │ /oauth2/auth  │
         └───────┬───────┘
                 │
         202 OK ─┴─ 401 → redirect to Auth0 login
                 │
                 ▼
         Backend Service
```

**Безопасность (3 уровня):**
1. **Network:** Tailscale (только tailnet devices могут подключиться)
2. **Transport:** TLS/HTTPS (сертификаты от Tailscale или cert-manager)
3. **Application:** Auth0 OIDC через oauth2-proxy

**Prerequisites:**
1. Auth0 Free account (до 25K MAU)
2. Doppler secrets: `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, `OAUTH2_PROXY_COOKIE_SECRET`

Docs:
- https://oauth2-proxy.github.io/oauth2-proxy/
- https://medium.com/@bdalpe/protecting-kubernetes-ingress-resources-with-traefik-forwardauth-and-oauth2-proxy-a7b3d330f276
- https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/user-management/auth0.md
- https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/generic-oauth/
- https://auth0.com/docs/quickstart/backend/java-spring-security5

## Фаза 7: Data
- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster
- [ ] Credentials через ESO
- [ ] Подключить приложение к БД

## Фаза 8: Observability
- [ ] kube-prometheus-stack
- [ ] Loki + Promtail
- [ ] ServiceMonitor для приложения

## Фаза 9: Backup
- [ ] MinIO
- [ ] Velero
- [ ] Тест: backup → delete → restore

## Фаза 10: Full Test (dev)
- [ ] Все pods Running
- [ ] Приложение отвечает
- [ ] Секреты синхронизируются
- [ ] CI/CD: push → autodeploy работает
- [ ] Метрики/логи работают
- [ ] Backup/restore работает

## Фаза 11: Production Environment
- [ ] Doppler config `prd` + Service Token
- [ ] K8s Secret `doppler-token-prd`
- [ ] ClusterSecretStore `doppler-prd`
- [ ] ApplicationSet для prd namespace
- [ ] Тест: деплой в prd
