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
- [ ] Traefik Ingress Controller (wave 9)
- [ ] cert-manager (wave 10)
- [ ] Tailscale Operator (wave 11)
- [ ] Tailscale Ingresses для admin UIs (wave 12)

Дока: [docs/phase5/](docs/phase5/)

| Компонент | Версия | Wave | Назначение |
|-----------|--------|------|------------|
| Traefik | 37.4.0 | 9 | Ingress Controller |
| cert-manager | 1.19.1 | 10 | TLS certificates |
| Tailscale Operator | 1.90.9 | 11 | Private networking |
| Tailscale Ingresses | - | 12 | Admin UIs access |

**Prerequisites:**
1. Tailscale ACL: добавить `tag:k8s-operator` и `tag:k8s`
2. Tailscale OAuth client (Devices Core, Auth Keys, Services Write)
3. Doppler secrets: `TS_OAUTH_CLIENT_ID`, `TS_OAUTH_CLIENT_SECRET`

**Access после синхронизации:**
- https://argocd (через Tailscale)
- https://longhorn (через Tailscale)
- https://traefik (через Tailscale)

## Фаза 6: Data
- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster
- [ ] Credentials через ESO
- [ ] Подключить приложение к БД

## Фаза 7: Observability
- [ ] kube-prometheus-stack
- [ ] Loki + Promtail
- [ ] ServiceMonitor для приложения

## Фаза 8: Backup
- [ ] MinIO
- [ ] Velero
- [ ] Тест: backup → delete → restore

## Фаза 9: Full Test (dev)
- [ ] Все pods Running
- [ ] Приложение отвечает
- [ ] Секреты синхронизируются
- [ ] CI/CD: push → autodeploy работает
- [ ] Метрики/логи работают
- [ ] Backup/restore работает

## Фаза 10: Production Environment
- [ ] Doppler config `prd` + Service Token
- [ ] K8s Secret `doppler-token-prd`
- [ ] ClusterSecretStore `doppler-prd`
- [ ] ApplicationSet для prd namespace
- [ ] Тест: деплой в prd
