# План практики GitOps Infrastructure

## Фаза 0: Подготовка
- [ ] VM (4 CPU, 8GB RAM, Ubuntu 22.04)
- [ ] k3s без traefik и servicelb
- [ ] kubectl, helm, k9s
- [ ] Тестовое приложение (простой REST API с /health, /metrics)
- [ ] GitHub репо: `test-deploy`, `test-infrastructure`

## Фаза 1: Core
- [ ] MetalLB + IPAddressPool
- [ ] Longhorn
- [ ] ArgoCD

## Фаза 2: GitOps
- [ ] SSH ключи для ArgoCD → GitHub
- [ ] AppProjects (platform, applications)
- [ ] Root Application (App of Apps)
- [ ] Library Helm chart в test-deploy
- [ ] ApplicationSet для сервисов
- [ ] Задеплоить тестовое приложение через ArgoCD

## Фаза 3: Secrets
- [ ] Doppler аккаунт + секреты
- [ ] External Secrets Operator
- [ ] ClusterSecretStore → Doppler
- [ ] ExternalSecret для приложения

## Фаза 4: Networking
- [ ] Traefik
- [ ] Tailscale Operator + Ingress для ArgoCD/Grafana
- [ ] (опционально) cert-manager

## Фаза 5: Data
- [ ] CloudNativePG operator
- [ ] PostgreSQL cluster
- [ ] Подключить приложение к БД
- [ ] (опционально) Strimzi Kafka

## Фаза 6: Observability
- [ ] kube-prometheus-stack (Prometheus + Grafana)
- [ ] Loki + Promtail
- [ ] ServiceMonitor для приложения
- [ ] Проверить метрики и логи в Grafana
- [ ] (опционально) Alertmanager → Telegram

## Фаза 7: Backup
- [ ] MinIO
- [ ] Velero
- [ ] Тест: backup → delete namespace → restore
- [ ] Scheduled backups

## Фаза 8: Full Test
- [ ] Все pods Running
- [ ] Приложение отвечает
- [ ] Секреты синхронизируются
- [ ] Метрики/логи собираются
- [ ] Backup/restore работает

## Фаза 9: Документация
- [ ] Гайды в brain (краткие, по делу)
- [ ] Перенос на mg-deploy / mg-infrastructure
