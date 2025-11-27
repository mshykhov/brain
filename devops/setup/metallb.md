# MetalLB Setup

LoadBalancer для bare-metal Kubernetes.

**Docs:** https://metallb.io/

## Способ установки

**GitOps через ArgoCD** (не руками!)

Файлы:
- `infrastructure/apps/templates/metallb.yaml` — Application для Helm chart
- `infrastructure/apps/templates/metallb-config.yaml` — Application для конфигурации
- `infrastructure/base/metallb/config.yaml` — IPAddressPool + L2Advertisement

## Конфигурация

```yaml
# infrastructure/base/metallb/config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.8.240-192.168.8.250  # Замени на свою подсеть!
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
```

## Проверка

```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get svc -A | grep LoadBalancer
```

## Timeline

| Дата | Действие |
|------|----------|
| 2024-11-27 | Создана GitOps структура, Helm chart v0.14.9 |
