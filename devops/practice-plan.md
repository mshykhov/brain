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

## Фаза 5: Networking
- [x] Tailscale Operator (wave 9-10) — kubectl через Tailscale
- [x] Tailscale Ingresses для admin UIs (wave 11)
- [ ] Traefik Ingress Controller (wave 12)
- [ ] cert-manager (wave 13)

Дока: [docs/phase5/](docs/phase5/)

| Компонент | Версия | Wave | Назначение |
|-----------|--------|------|------------|
| Tailscale Credentials | - | 9 | ExternalSecret для OAuth |
| Tailscale Operator | 1.90.9 | 10 | API Server Proxy (kubectl) |
| Tailscale Ingresses | - | 11 | Admin UIs (ArgoCD, Longhorn) |
| Traefik | TBD | 12 | Public Ingress Controller |
| cert-manager | TBD | 13 | TLS certificates |

**Prerequisites (выполнено):**
1. ✅ Tailscale ACL: `tagOwners`, `acls`, `grants`, `ssh` секции
2. ✅ Tailscale OAuth client (Devices Core, Auth Keys, Services Write)
3. ✅ HTTPS Certificates и MagicDNS enabled
4. ✅ Doppler secrets: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_CLIENT_SECRET`

**Важно:** ACL должен содержать `acls` секцию, иначе потеряется SSH доступ!

**Access (работает):**
- `tailscale configure kubeconfig tailscale-operator` → kubectl
- https://argocd.tail876052.ts.net (ArgoCD UI)
- https://longhorn.tail876052.ts.net (Longhorn UI)

**Будущее улучшение — Centralized Auth (Auth0 + Traefik OIDC):**

Варианты:
1. **traefik-oidc-auth plugin** — бесплатный OIDC плагин для Traefik
2. **ForwardAuth middleware** — делегирует auth внешнему сервису
3. **Traefik Hub OIDC** — только платная версия

Рекомендуется: `traefik-oidc-auth` + Auth0 (бесплатно до 25K MAU)

Преимущества:
- Единая точка управления доступом (Auth0 dashboard)
- Role-based access через claims (`groups: admin`)
- Один middleware для всех admin UI

Требования:
- Переключить admin UI с Tailscale Ingress на Traefik IngressRoute
- Auth0 аккаунт + Application (Regular Web App)
- Doppler secrets: `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`, `OIDC_SECRET`

Docs:
- https://github.com/sevensolutions/traefik-oidc-auth
- https://auth0.com/docs/get-started

## Фаза 6: Centralized Auth (Auth0)
- [ ] Auth0 аккаунт + tenant
- [ ] Auth0 Applications (ArgoCD, Traefik, example-api)
- [ ] Auth0 API для example-api (JWT validation)
- [ ] ArgoCD OIDC config (встроенная поддержка)
- [ ] Traefik OIDC middleware (traefik-oidc-auth plugin)
- [ ] Longhorn через Traefik ForwardAuth
- [ ] example-api: JWT validation в Spring Security
- [ ] RBAC через Auth0 roles/groups

Дока: [docs/phase6/](docs/phase6/)

| Компонент | Встроенный OIDC? | Auth метод | Network |
|-----------|------------------|------------|---------|
| ArgoCD | ✅ | Built-in OIDC → Auth0 | Tailscale |
| Grafana | ✅ | `[auth.generic_oauth]` → Auth0 | Tailscale |
| Longhorn | ❌ | Traefik ForwardAuth → Auth0 | Tailscale |
| Prometheus | ❌ | Traefik ForwardAuth → Auth0 | Tailscale |
| AlertManager | ❌ | Traefik ForwardAuth → Auth0 | Tailscale |
| example-api (web) | - | Traefik OIDC middleware | Public |
| example-api (API) | - | JWT verification | Public |

**Архитектура:**
```
                         ┌─────────────┐
                         │   Auth0     │
                         │   (IdP)     │
                         └──────┬──────┘
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
     ┌────────────┐      ┌────────────┐      ┌────────────┐
     │  ArgoCD    │      │  Traefik   │      │ example-api│
     │ OIDC Login │      │ OIDC Plugin│      │ JWT Verify │
     └─────┬──────┘      └─────┬──────┘      └─────┬──────┘
           │                   │                   │
    Tailscale Ingress    Tailscale LB         Public LB
     (argocd.ts.net)    (traefik.ts.net)    (api.example.com)
           │                   │
           │            ┌──────┴──────┐
           │            ▼             ▼
           │      ┌──────────┐  ┌──────────┐
           │      │ Longhorn │  │Prometheus│
           │      └──────────┘  └──────────┘
           ▼
    ArgoCD has built-in OIDC,
    no middleware needed
```

**Ключевой момент:**
- Traefik как LoadBalancer через Tailscale (`loadBalancerClass: tailscale`)
- ForwardAuth middleware работает внутри Traefik
- Сервисы без OIDC (Longhorn, Prometheus) защищены через Traefik middleware

**TLS/HTTPS:**
- Traefik имеет встроенный `certificateResolver: tailscale`
- Сертификаты от Tailscale (Let's Encrypt) — автоматически
- cert-manager НЕ нужен для internal сервисов (только для public)

```yaml
# Traefik config
certificatesResolvers:
  tailscale:
    tailscale: {}

# IngressRoute
tls:
  certResolver: tailscale
```

**Безопасность (3 уровня):**
1. Network: Tailscale (только tailnet devices)
2. Transport: TLS/HTTPS (сертификаты от Tailscale)
3. Application: Auth0 OIDC (identity verification)

Docs:
- https://doc.traefik.io/traefik/reference/install-configuration/tls/certificate-resolvers/tailscale/
- https://traefik.io/blog/exploring-the-tailscale-traefik-proxy-integration
- https://joshrnoll.com/using-traefik-on-kubernetes-over-tailscale/

**Prerequisites:**
1. Auth0 Free account (до 25K MAU)
2. Doppler secrets: `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`

Docs:
- https://github.com/argoproj/argo-cd/blob/master/docs/operator-manual/user-management/auth0.md
- https://github.com/sevensolutions/traefik-oidc-auth
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
