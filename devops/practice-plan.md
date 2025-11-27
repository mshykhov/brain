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
│   └── root.yaml                      # Точка входа (apply вручную)
├── apps/
│   ├── Chart.yaml
│   ├── values.yaml                    # Общие настройки
│   └── templates/
│       ├── metallb.yaml               # Wave 1
│       ├── metallb-config.yaml        # Wave 2
│       └── longhorn.yaml              # Wave 3
│       # Добавляй новые компоненты сюда:
│       # ├── traefik.yaml             # Wave 4 (Фаза 4)
│       # ├── tailscale.yaml           # Wave 5 (Фаза 4)
│       # └── prometheus-stack.yaml    # Wave 10 (Фаза 6)
└── manifests/
    ├── argocd-config/
    │   └── repository-secret.example.yaml  # Шаблон (НЕ коммитить реальный!)
    └── metallb-config/
        └── config.yaml                # IPAddressPool + L2Advertisement
```

> **Важно:** Приватные ключи НИКОГДА не коммитятся в git!
> `.example.yaml` — только шаблон, реальный секрет создаётся локально.

### Как работает
```
kubectl apply -f bootstrap/root.yaml
              │
              ▼
Root Application синхронизирует apps/ Helm chart
(каждый файл в templates/ = отдельное Application)
              │
              ▼
Child Applications (по sync-wave):
  Wave 1: metallb.yaml       → Helm chart
  Wave 2: metallb-config.yaml → Raw manifests
  Wave 3: longhorn.yaml      → Helm chart
```

### Bootstrap (один раз)

```bash
# 1. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 2. Connect repo (только для PRIVATE repos!)
# Docs: https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd-key -N ""
cat ~/.ssh/argocd-key.pub  # → GitHub repo → Settings → Deploy keys → Add
# Создай секрет из шаблона (НЕ коммить!):
cp manifests/argocd-config/repository-secret.example.yaml /tmp/secret.yaml
vim /tmp/secret.yaml  # вставь приватный ключ
kubectl apply -f /tmp/secret.yaml && rm /tmp/secret.yaml

# 3. Apply root
kubectl apply -f bootstrap/root.yaml

# 4. Password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# 5. Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
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
