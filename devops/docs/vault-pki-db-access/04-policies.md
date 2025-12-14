# Vault Policies for RBAC

## 1. Policy Structure

```
Auth0 Role              Vault Policy          What it allows
────────────────────────────────────────────────────────────
db-admin             →  pki-admin          →  Issue any cert
db-readonly          →  pki-readonly       →  Issue readonly certs
db-readwrite         →  pki-readwrite      →  Issue readwrite certs
db-app-blackpoint    →  pki-app-blackpoint →  Issue blackpoint certs
db-app-notifier      →  pki-app-notifier   →  Issue notifier certs
db-env-dev           →  pki-env-dev        →  Issue dev certs
db-env-prd           →  pki-env-prd        →  Issue prd certs
```

## 2. Create Policies

### pki-admin (полный доступ)

```bash
kubectl exec -n vault vault-0 -- vault policy write pki-admin - <<'EOF'
# Full PKI access
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
EOF
```

### pki-readonly (только readonly certs)

```bash
kubectl exec -n vault vault-0 -- vault policy write pki-readonly - <<'EOF'
# Issue readonly certificates only
path "pki_int/issue/db-readonly" {
  capabilities = ["create", "update"]
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF
```

### pki-readwrite (readwrite certs)

```bash
kubectl exec -n vault vault-0 -- vault policy write pki-readwrite - <<'EOF'
# Issue readwrite certificates
path "pki_int/issue/db-readwrite" {
  capabilities = ["create", "update"]
}

path "pki_int/issue/db-readonly" {
  capabilities = ["create", "update"]
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF
```

### pki-app-blackpoint

```bash
kubectl exec -n vault vault-0 -- vault policy write pki-app-blackpoint - <<'EOF'
# Access to blackpoint database certs
path "pki_int/issue/db-*" {
  capabilities = ["create", "update"]
  allowed_parameters = {
    "common_name" = ["*@*"]
    "ttl" = ["8760h"]
  }
  # Additional restriction via certificate CN validation on DB side
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF
```

### pki-env-dev

```bash
kubectl exec -n vault vault-0 -- vault policy write pki-env-dev - <<'EOF'
# Access to dev environment certs
path "pki_int/issue/db-*" {
  capabilities = ["create", "update"]
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF
```

### pki-env-prd

```bash
kubectl exec -n vault vault-0 -- vault policy write pki-env-prd - <<'EOF'
# Access to prd environment certs
path "pki_int/issue/db-*" {
  capabilities = ["create", "update"]
}

path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOF
```

## 3. Policy Aggregation

Когда пользователь имеет несколько Auth0 ролей, политики агрегируются:

```
User: developer@company.com
Auth0 Roles: db-readonly, db-app-blackpoint, db-env-dev

Vault Policies:
  - pki-readonly
  - pki-app-blackpoint
  - pki-env-dev

Effective Access: Union of all policies
  - Can issue db-readonly certs ✅
  - Can read CA cert ✅
```

## 4. Verify Policies

```bash
# List policies
kubectl exec -n vault vault-0 -- vault policy list

# Read specific policy
kubectl exec -n vault vault-0 -- vault policy read pki-admin

# Test policy (as user)
vault login -method=oidc
vault token capabilities pki_int/issue/db-readonly
# Should output: create, update
```

## 5. Terraform Configuration

`terraform/vault-policies.tf`:

```hcl
resource "vault_policy" "pki_admin" {
  name   = "pki-admin"
  policy = <<EOT
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
EOT
}

resource "vault_policy" "pki_readonly" {
  name   = "pki-readonly"
  policy = <<EOT
path "pki_int/issue/db-readonly" {
  capabilities = ["create", "update"]
}
path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOT
}

resource "vault_policy" "pki_readwrite" {
  name   = "pki-readwrite"
  policy = <<EOT
path "pki_int/issue/db-readwrite" {
  capabilities = ["create", "update"]
}
path "pki_int/issue/db-readonly" {
  capabilities = ["create", "update"]
}
path "pki_int/cert/ca" {
  capabilities = ["read"]
}
EOT
}
```

## Next Steps

→ [05-database-config.md](05-database-config.md)
