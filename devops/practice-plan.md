# План практики GitOps Infrastructure

> **Принцип:** Всё управляется через GitOps. Вручную устанавливается ТОЛЬКО ArgoCD.

## Фаза 0: Подготовка
- [x] VM (4 CPU, 8GB RAM, Ubuntu 22.04+)
- [x] k3s без traefik и servicelb
- [x] kubectl, helm, k9s
- [x] GitHub репо: `example-infrastructure`
- [x] GitHub репо: `example-deploy`
- [x] GitHub репо: `example-api` (Kotlin/Spring Boot)

```bash
curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh | sudo bash
```

Дока: [docs/phase0-k3s.md](docs/phase0-k3s.md)

## Фаза 1: Core Infrastructure
- [x] ArgoCD
- [x] MetalLB
- [x] Longhorn
- [x] Tailscale SSH

Дока: [docs/phase1-argocd.md](docs/phase1-argocd.md)

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

## Фаза 3: Secrets
- [ ] Doppler аккаунт (бесплатный Developer план)
- [ ] Создать проект и environment в Doppler
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
