# План практики GitOps Infrastructure

> **Принцип:** Всё управляется через GitOps. Вручную устанавливается ТОЛЬКО ArgoCD.

## Фаза 0: Подготовка
- [x] VM (4 CPU, 8GB RAM, Ubuntu 22.04+)
- [x] k3s без traefik и servicelb
- [x] kubectl, helm, k9s
- [ ] Тестовое приложение (простой REST API с /health, /metrics)
- [x] GitHub репо: `example-infrastructure`

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

## Фаза 2: GitOps
- [ ] AppProjects (platform, applications)
- [ ] Library Helm chart
- [ ] ApplicationSet для сервисов
- [ ] Задеплоить тестовое приложение

## Фаза 3: Secrets
- [ ] Doppler аккаунт + секреты
- [ ] External Secrets Operator
- [ ] ClusterSecretStore → Doppler
- [ ] ExternalSecret для приложения

## Фаза 4: Networking
- [ ] Traefik
- [ ] Tailscale Operator (Ingress для ArgoCD/Grafana)
- [ ] (опционально) cert-manager

## Фаза 5: Data
- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster
- [ ] Подключить приложение к БД

## Фаза 6: Observability
- [ ] kube-prometheus-stack
- [ ] Loki + Promtail
- [ ] ServiceMonitor для приложения

## Фаза 7: Backup
- [ ] MinIO
- [ ] Velero
- [ ] Тест: backup → delete → restore

## Фаза 8: Full Test
- [ ] Все pods Running
- [ ] Приложение отвечает
- [ ] Секреты синхронизируются
- [ ] Метрики/логи работают
- [ ] Backup/restore работает
