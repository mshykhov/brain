# Vault Policies (GitOps)

Policies настраиваются через `vault-config` chart и применяются автоматически.

## 1. Policy Structure

```
Auth0 Role        →  Vault Policy    →  PKI Access
─────────────────────────────────────────────────────
db-admin          →  pki-admin       →  Issue any certificate
db-readonly       →  pki-readonly    →  Issue readonly certs only
db-readwrite      →  pki-readwrite   →  Issue readonly + readwrite certs
```

## 2. Policies Configuration

`infrastructure/charts/vault-config/values.yaml`:

```yaml
policies:
  pki-admin: |
    path "pki_int/issue/*" {
      capabilities = ["create", "update"]
    }
    path "pki_int/roles/*" {
      capabilities = ["read", "list"]
    }
    path "pki_int/certs/*" {
      capabilities = ["read", "list"]
    }
    path "pki/cert/ca" {
      capabilities = ["read"]
    }
    path "pki_int/cert/ca" {
      capabilities = ["read"]
    }

  pki-readonly: |
    path "pki_int/issue/db-readonly" {
      capabilities = ["create", "update"]
    }
    path "pki_int/cert/ca" {
      capabilities = ["read"]
    }

  pki-readwrite: |
    path "pki_int/issue/db-readwrite" {
      capabilities = ["create", "update"]
    }
    path "pki_int/issue/db-readonly" {
      capabilities = ["create", "update"]
    }
    path "pki_int/cert/ca" {
      capabilities = ["read"]
    }
```

## 3. External Groups Mapping

```yaml
externalGroups:
  - name: "db-admin"
    policies:
      - "pki-admin"
  - name: "db-readonly"
    policies:
      - "pki-readonly"
  - name: "db-readwrite"
    policies:
      - "pki-readwrite"
```

## 4. Policy Aggregation

Когда пользователь имеет несколько Auth0 ролей, политики агрегируются:

```
User: developer@company.com
Auth0 Roles: db-readonly, db-readwrite

Vault Policies:
  - pki-readonly
  - pki-readwrite

Effective Access: Union of all policies
```

## 5. Verify Policies

```bash
# List policies
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault policy list"

# Read specific policy
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault policy read pki-admin"

# Test access (after OIDC login)
vault token capabilities pki_int/issue/db-readonly
# Output: create, update
```

## 6. Adding New Policies

Для добавления новой policy:

1. Добавить в `values.yaml`:
   ```yaml
   policies:
     pki-new-policy: |
       path "pki_int/issue/new-role" {
         capabilities = ["create", "update"]
       }
   ```

2. Добавить external group:
   ```yaml
   externalGroups:
     - name: "new-auth0-role"
       policies:
         - "pki-new-policy"
   ```

3. Создать роль в Auth0 с именем `new-auth0-role`

4. Push to git → ArgoCD applies

## Next Steps

→ [05-database-config.md](05-database-config.md)
