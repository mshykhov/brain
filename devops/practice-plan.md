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

## Фаза 2: GitOps Structure
- [x] Library Helm chart (`example-deploy/_library/`)
- [x] Helm chart для example-api (`example-deploy/services/example-api/`)
- [x] ApplicationSet для сервисов (`example-infrastructure/apps/templates/services-appset.yaml`)
- [ ] SSH ключ для example-deploy в ArgoCD
- [ ] Закоммитить и запушить example-deploy
- [ ] Закоммитить и запушить example-infrastructure

Дока: [docs/phase2/](docs/phase2/)

## Фаза 3: Secrets
- [ ] Doppler аккаунт (бесплатный Developer план)
- [ ] Создать проект `example` и config `dev` в Doppler
- [ ] External Secrets Operator (через ArgoCD)
- [ ] Doppler Service Token → K8s Secret (вручную, один раз)
- [ ] ClusterSecretStore → Doppler
- [ ] Docker Registry credentials через ESO

## Фаза 4: CI/CD Automation
- [ ] GitHub Actions для example-api (build + push Docker image)
- [ ] ArgoCD Image Updater
- [ ] Аннотации для автообновления образов
- [ ] Тест: push tag → автодеплой

## Фаза 5: Networking
- [ ] Traefik
- [ ] Tailscale Operator (Ingress для ArgoCD/Grafana)
- [ ] (опционально) cert-manager

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

## Фаза 9: Full Test
- [ ] Все pods Running
- [ ] Приложение отвечает
- [ ] Секреты синхронизируются
- [ ] CI/CD: push → autodeploy работает
- [ ] Метрики/логи работают
- [ ] Backup/restore работает
