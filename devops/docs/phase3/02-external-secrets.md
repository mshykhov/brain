# Phase 3: External Secrets Operator

## Зачем

External Secrets Operator (ESO) синхронизирует секреты из внешних хранилищ (Doppler, AWS Secrets Manager, Vault и др.) в Kubernetes Secrets.

## Установка через ArgoCD

Файл: `example-infrastructure/apps/templates/external-secrets.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    chart: external-secrets
    targetRevision: "1.1.0"
    helm:
      values: |
        installCRDs: true
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Sync Wave

Wave 10 — после базовой инфраструктуры (MetalLB, Longhorn), но до сервисов (wave 100).

| Wave | Компонент |
|------|-----------|
| 1 | MetalLB |
| 2 | MetalLB Config |
| 3 | Longhorn |
| 10 | External Secrets Operator |
| 100 | Services (ApplicationSet) |

## Проверка

```bash
# Application в ArgoCD
kubectl get applications -n argocd

# Pods ESO
kubectl get pods -n external-secrets

# CRDs установлены
kubectl get crd | grep external-secrets
```

Ожидаемые CRDs:
- `externalsecrets.external-secrets.io`
- `secretstores.external-secrets.io`
- `clustersecretstores.external-secrets.io`

## Следующий шаг

[ClusterSecretStore для Doppler](cluster-secret-store.md)
