# Vault Setup

## ArgoCD Application

```yaml
# infrastructure/apps/templates/core/vault.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault
  namespace: argocd
spec:
  project: infrastructure
  sources:
    - repoURL: https://helm.releases.hashicorp.com
      chart: vault
      targetRevision: "0.30.0"
      helm:
        valueFiles:
          - $values/helm-values/core/vault.yaml
    - repoURL: {{ .Values.spec.source.repoURL }}
      targetRevision: {{ .Values.spec.source.targetRevision }}
      ref: values
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: vault
```

## Initialize Vault

После деплоя Vault нужно инициализировать (один раз):

```bash
# Подключиться к поду
kubectl exec -it vault-0 -n vault -- sh

# Инициализация (сохранить вывод!)
vault operator init -key-shares=1 -key-threshold=1

# Unseal
vault operator unseal <UNSEAL_KEY>
```

## Сохранить в Doppler (shared)

| Key | Value |
|-----|-------|
| `VAULT_ROOT_TOKEN` | Root token из init |
| `VAULT_UNSEAL_KEY` | Unseal key из init |

## vault-config Chart

Автоматическая конфигурация через Kubernetes Job:

- PKI Root CA (10 лет)
- PKI Intermediate CA (5 лет)
- PKI Roles: db-admin, db-readonly, db-readwrite
- Vault Policies
- OIDC Authentication (Auth0)
- External Groups mapping

Конфигурация в `infrastructure/charts/vault-config/values.yaml`.

## Проверка

```bash
# PKI
vault secrets list
vault read pki_int/cert/ca

# OIDC
vault auth list
vault read auth/oidc/config
```
