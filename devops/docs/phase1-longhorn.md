# Phase 1: Longhorn

**Version:** 1.10.1
**Docs:** https://longhorn.io/
**Установка:** GitOps (ArgoCD)

## Зачем

Distributed storage для Kubernetes. Даёт PersistentVolumes на bare-metal.

## Файлы в example-infrastructure

```
apps/templates/longhorn.yaml  # Application (Helm chart)
```

## Helm Values

```yaml
preUpgradeChecker:
  jobEnabled: false  # Важно для ArgoCD!
```

Без этого ArgoCD зависнет на Job который не завершается.

## Sync Wave

- Wave 3: После MetalLB (нужен LoadBalancer для UI)

## Проверка

```bash
kubectl get pods -n longhorn-system
kubectl get storageclass  # Должен быть longhorn (default)
kubectl get pv,pvc -A
```

## UI

```bash
kubectl port-forward svc/longhorn-frontend -n longhorn-system 9000:80
# http://localhost:9000
```

## Требования

- Kubernetes >= 1.25
- open-iscsi на нодах (устанавливается в phase0-setup.sh)
