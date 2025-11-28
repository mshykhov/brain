# Phase 3: ClusterSecretStore

## Зачем

ClusterSecretStore — cluster-wide ресурс, который определяет как ESO подключается к Doppler. Доступен из любого namespace.

## Структура

```
example-infrastructure/
├── apps/templates/
│   └── secret-stores.yaml              # ArgoCD Application (один на все env)
└── manifests/cluster-secret-stores/
    ├── doppler-dev.yaml                # ClusterSecretStore dev
    └── doppler-prd.yaml                # ClusterSecretStore prd (Phase 10)
```

## ArgoCD Application

Файл: `apps/templates/secret-stores.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: secret-stores
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "11"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: git@github.com:mshykhov/example-infrastructure.git
    targetRevision: master
    path: manifests/cluster-secret-stores
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Один Application деплоит все ClusterSecretStore из папки.

## ClusterSecretStore манифест

Файл: `manifests/cluster-secret-stores/doppler-dev.yaml`

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: doppler-dev
spec:
  provider:
    doppler:
      auth:
        secretRef:
          dopplerToken:
            name: doppler-token-dev
            namespace: external-secrets
            key: dopplerToken
```

## Sync Wave

| Wave | Компонент |
|------|-----------|
| 10 | External Secrets Operator |
| 11 | ClusterSecretStores |
| 100 | Services |

## Проверка

```bash
# Application в ArgoCD
kubectl get applications -n argocd | grep secret-stores

# ClusterSecretStore создан
kubectl get clustersecretstores

# Статус (должен быть Valid)
kubectl describe clustersecretstore doppler-dev
```

Ожидаемый статус:
```
Status:
  Conditions:
    Status:  True
    Type:    Ready
```

## Добавление prd (Phase 10)

Просто добавить файл `manifests/cluster-secret-stores/doppler-prd.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: doppler-prd
spec:
  provider:
    doppler:
      auth:
        secretRef:
          dopplerToken:
            name: doppler-token-prd
            namespace: external-secrets
            key: dopplerToken
```

ArgoCD автоматически подхватит новый файл.

## Следующий шаг

[05. Docker credentials](05-docker-credentials.md)
