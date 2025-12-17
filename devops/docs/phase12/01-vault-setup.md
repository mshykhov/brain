# Vault Setup

## 1. ArgoCD Application

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
    - repoURL: <repo>
      ref: values
  destination:
    namespace: vault
```

## 2. Initialize Vault (первый раз)

```bash
kubectl exec -it vault-0 -n vault -- sh

# Инициализация
vault operator init -key-shares=1 -key-threshold=1

# Сохрани: Root Token, Unseal Key
```

## 3. Сохранить в Doppler (shared)

| Key | Value |
|-----|-------|
| VAULT_ROOT_TOKEN | Root token |
| VAULT_UNSEAL_KEY | Unseal key |

## 4. vault-config Chart

Автоматическая конфигурация через Kubernetes Job.

Что настраивается:
- Database Secrets Engine (connections, roles)
- OIDC Authentication (Auth0)
- Vault Policies
- External Groups (Auth0 → Vault mapping)
- Audit logging

### Добавление новой БД

1. Добавить в `vault-config/values.yaml`:

```yaml
database:
  databases:
    myapp:
      dev:
        host: "myapp-db-dev-cluster-rw.myapp-dev.svc"
        port: 5432
        database: myapp
        sslmode: require
        username: "postgres"
        secretRef:
          namespace: myapp-dev
          name: myapp-db-dev-cluster-superuser
          key: password
        access: [readonly, readwrite, admin]
```

2. Создать Auth0 роль: `db:myapp:dev:readonly` (и другие)

3. Push → ArgoCD автоматически применит

## 5. Проверка

```bash
# Secrets engines
vault secrets list

# Database connections
vault list database/config

# Database roles
vault list database/roles

# OIDC
vault auth list
```
