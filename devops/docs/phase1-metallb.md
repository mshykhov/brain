# Phase 1: MetalLB

**Version:** 0.15.2
**Docs:** https://metallb.io/
**Установка:** GitOps (ArgoCD)

## Зачем

LoadBalancer для bare-metal. Без него `type: LoadBalancer` будет вечно в `<pending>`.

## Файлы в test-infrastructure

```
apps/templates/metallb.yaml        # Application (Helm chart)
apps/templates/metallb-config.yaml # Application (raw manifests)
manifests/metallb-config/config.yaml # IPAddressPool + L2Advertisement
```

## Конфигурация IP

Редактировать `manifests/metallb-config/config.yaml`:

```yaml
spec:
  addresses:
    - 192.168.8.240-192.168.8.250  # Твоя подсеть!
```

## Sync Waves

- Wave 1: MetalLB Helm chart
- Wave 2: MetalLB Config (IPAddressPool)

Config должен применяться ПОСЛЕ установки CRD из Helm chart.

## Проверка

```bash
kubectl get pods -n metallb-system
kubectl get ipaddresspool -n metallb-system
kubectl get svc -A | grep LoadBalancer  # Должен быть EXTERNAL-IP
```
