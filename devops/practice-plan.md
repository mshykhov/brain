# План практики GitOps Infrastructure

> **Принцип:** Всё управляется через GitOps. Вручную устанавливается ТОЛЬКО ArgoCD.

## Фаза 0: Подготовка
- [ ] VM (4 CPU, 8GB RAM, Ubuntu 22.04)
- [ ] k3s без traefik и servicelb → `scripts/phase0-setup.sh`
- [ ] kubectl, helm, k9s → `scripts/phase0-setup.sh`
- [ ] Тестовое приложение (простой REST API с /health, /metrics)
- [ ] GitHub репо: `test-deploy`, `test-infrastructure`

### Скрипт установки
```bash
curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh | sudo bash
```

## Фаза 1: Core Infrastructure

### Структура test-infrastructure репо
```
infrastructure/
├── bootstrap/
│   └── root.yaml              # Точка входа (apply вручную)
├── apps/
│   ├── Chart.yaml
│   ├── values.yaml            # Список приложений
│   └── templates/
│       └── applications.yaml  # Генерирует Application CRs
└── manifests/
    └── metallb-config/
        └── config.yaml        # IPAddressPool + L2Advertisement
```

### Как работает
```
1. kubectl apply -f bootstrap/root.yaml
                    │
                    ▼
2. Root App синхронизирует apps/ Helm chart
   → Генерирует Application CRs из values.yaml
                    │
                    ▼
3. Child Applications устанавливают компоненты по sync-wave:
   Wave 1: MetalLB (Helm)
   Wave 2: MetalLB Config (manifests)
   Wave 3: Longhorn (Helm)
```

### Bootstrap (один раз)
```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml

# 2. Wait
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 3. Apply root
kubectl apply -f bootstrap/root.yaml

# 4. Password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Проверка
- [ ] ArgoCD UI доступен (port-forward 8080:443)
- [ ] Root Application: Synced
- [ ] MetalLB: Running в metallb-system
- [ ] MetalLB Config: IPAddressPool создан
- [ ] Longhorn: Running в longhorn-system
- [ ] `kubectl get svc` показывает EXTERNAL-IP для LoadBalancer

### Компоненты Фазы 1

| Компонент | Версия | Sync Wave | Docs |
|-----------|--------|-----------|------|
| MetalLB | 0.15.2 | 1 | https://metallb.io/ |
| MetalLB Config | - | 2 | https://metallb.io/configuration/ |
| Longhorn | 1.10.1 | 3 | https://longhorn.io/ |

> **Note:** Longhorn требует Kubernetes >= 1.25

## Фаза 2: GitOps
- [ ] SSH ключи для ArgoCD → GitHub (private repos)
- [ ] AppProjects (platform, applications)
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

## Фаза 9: Production
- [ ] Перенос на mg-infrastructure
- [ ] Документация
