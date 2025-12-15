# Database Secrets Engine (Dynamic Credentials)

Динамические credentials для PostgreSQL с мгновенной revocation при изменении Auth0 ролей.

## Архитектура

```
┌────────────────────────────────────────────────────────────┐
│ Auth0 Roles (Modular)                                       │
├────────────────────────────────────────────────────────────┤
│ Access Levels:     App Access:        Environment:          │
│ ├─ db-readonly     ├─ db-app-blackpoint  ├─ db-env-dev     │
│ ├─ db-readwrite    └─ db-app-notifier    └─ db-env-prd     │
│ └─ db-admin                                                 │
└───────────────────────────┬────────────────────────────────┘
                            │ Auth0 Action (3D cross-product)
                            ▼
┌────────────────────────────────────────────────────────────┐
│ Computed Roles → Vault                                      │
│ db:blackpoint:dev:readonly, db:blackpoint:prd:readwrite... │
└───────────────────────────┬────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────┐
│ Vault Database Secrets Engine                               │
│                                                             │
│ Connections:              Roles:                            │
│ ├─ blackpoint-dev         ├─ blackpoint-dev-readonly        │
│ ├─ blackpoint-prd         ├─ blackpoint-dev-readwrite       │
│ ├─ notifier-dev           ├─ blackpoint-prd-readonly        │
│ └─ notifier-prd           └─ ...                            │
└───────────────────────────┬────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────┐
│ PostgreSQL (CNPG)                                           │
│ Dynamic user: v-oidc-readonly-HfgL2k (TTL: 24h)            │
│ Auto-revoked on expiry                                      │
└────────────────────────────────────────────────────────────┘
```

## 1. Auth0 Configuration

### Roles Structure

| Role | Description |
|------|-------------|
| `db-readonly` | Database read-only access |
| `db-readwrite` | Database read-write access |
| `db-admin` | Full database admin access |
| `db-app-blackpoint` | Access to Blackpoint databases |
| `db-app-notifier` | Access to Notifier databases |
| `db-env-dev` | Access to dev environment |
| `db-env-prd` | Access to prd environment |

### Auth0 Action: Compute Database Roles

**Actions** → **Library** → **Add Vault Roles** → Edit

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://vault';
  const roles = event.authorization?.roles || [];

  // Extract role categories
  const accessLevels = roles
    .filter(r => ['db-readonly', 'db-readwrite', 'db-admin'].includes(r))
    .map(r => r.replace('db-', ''));

  const apps = roles
    .filter(r => r.startsWith('db-app-'))
    .map(r => r.replace('db-app-', ''));

  const envs = roles
    .filter(r => r.startsWith('db-env-'))
    .map(r => r.replace('db-env-', ''));

  // Compute 3D cross-product: app × env × access
  // Example: db-app-blackpoint + db-env-dev + db-readonly → db:blackpoint:dev:readonly
  const computedRoles = [];
  for (const app of apps) {
    for (const env of envs) {
      for (const access of accessLevels) {
        computedRoles.push(`db:${app}:${env}:${access}`);
      }
    }
  }

  // Add non-db roles (infra-admins, argocd-admins, etc.)
  const otherRoles = roles.filter(r => !r.startsWith('db-'));

  api.idToken.setCustomClaim(`${namespace}/roles`, [...computedRoles, ...otherRoles]);
};
```

### Example

User has roles:
- `db-readonly`
- `db-readwrite`
- `db-app-blackpoint`
- `db-env-dev`
- `db-env-prd`

Computed roles sent to Vault:
```
db:blackpoint:dev:readonly
db:blackpoint:dev:readwrite
db:blackpoint:prd:readonly
db:blackpoint:prd:readwrite
```

## 2. Vault Configuration

### Enable Database Secrets Engine

```bash
vault secrets enable database
```

### Configure Database Connection

```bash
# Blackpoint DEV
vault write database/config/blackpoint-dev \
    plugin_name=postgresql-database-plugin \
    allowed_roles="blackpoint-dev-readonly,blackpoint-dev-readwrite,blackpoint-dev-admin" \
    connection_url="postgresql://{{username}}:{{password}}@blackpoint-api-dev-rw.blackpoint-api-dev.svc:5432/blackpoint?sslmode=require" \
    username="vault_admin" \
    password="xxx"

# Blackpoint PRD
vault write database/config/blackpoint-prd \
    plugin_name=postgresql-database-plugin \
    allowed_roles="blackpoint-prd-readonly,blackpoint-prd-readwrite,blackpoint-prd-admin" \
    connection_url="postgresql://{{username}}:{{password}}@blackpoint-api-prd-rw.blackpoint-api-prd.svc:5432/blackpoint?sslmode=require" \
    username="vault_admin" \
    password="xxx"
```

### Configure Database Roles

```bash
# Blackpoint DEV - Readonly
vault write database/roles/blackpoint-dev-readonly \
    db_name=blackpoint-dev \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT CONNECT ON DATABASE blackpoint TO \"{{name}}\"; \
        GRANT USAGE ON SCHEMA public TO \"{{name}}\"; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
    default_ttl="24h" \
    max_ttl="72h"

# Blackpoint DEV - Readwrite
vault write database/roles/blackpoint-dev-readwrite \
    db_name=blackpoint-dev \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT CONNECT ON DATABASE blackpoint TO \"{{name}}\"; \
        GRANT USAGE ON SCHEMA public TO \"{{name}}\"; \
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\"; \
        GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";" \
    revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
    default_ttl="24h" \
    max_ttl="72h"

# Blackpoint DEV - Admin
vault write database/roles/blackpoint-dev-admin \
    db_name=blackpoint-dev \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' SUPERUSER;" \
    revocation_statements="DROP ROLE IF EXISTS \"{{name}}\";" \
    default_ttl="8h" \
    max_ttl="24h"
```

### Vault Policies

```hcl
# database-blackpoint-dev-readonly.hcl
path "database/creds/blackpoint-dev-readonly" {
  capabilities = ["read"]
}

# database-blackpoint-dev-readwrite.hcl
path "database/creds/blackpoint-dev-readwrite" {
  capabilities = ["read"]
}
path "database/creds/blackpoint-dev-readonly" {
  capabilities = ["read"]
}

# database-blackpoint-dev-admin.hcl
path "database/creds/blackpoint-dev-*" {
  capabilities = ["read"]
}
```

### External Groups

```yaml
externalGroups:
  # Database access - computed from Auth0 Action
  - name: "db:blackpoint:dev:readonly"
    policies: ["database-blackpoint-dev-readonly"]
  - name: "db:blackpoint:dev:readwrite"
    policies: ["database-blackpoint-dev-readwrite"]
  - name: "db:blackpoint:dev:admin"
    policies: ["database-blackpoint-dev-admin"]
  - name: "db:blackpoint:prd:readonly"
    policies: ["database-blackpoint-prd-readonly"]
  # ... etc for all combinations
```

## 3. PostgreSQL Preparation

Create vault admin user in each database:

```sql
-- Option 1: Superuser (simpler)
CREATE ROLE vault_admin WITH SUPERUSER LOGIN PASSWORD 'secure-password';

-- Option 2: Limited privileges (more secure)
CREATE ROLE vault_admin WITH CREATEROLE LOGIN PASSWORD 'secure-password';
GRANT ALL ON DATABASE blackpoint TO vault_admin;
GRANT ALL ON SCHEMA public TO vault_admin;
```

## 4. User Workflow

### Get Database Credentials

```bash
# 1. Login to Vault (once per 7 days)
vault login -method=oidc

# 2. Get credentials (once per day)
vault read database/creds/blackpoint-dev-readonly

# Output:
# username    v-oidc-readonly-HfgL2k
# password    A1b2C3d4-xxxxx
# lease_id    database/creds/blackpoint-dev-readonly/abc123
# ttl         24h

# 3. Connect
psql "host=blackpoint-dev.ts.net user=v-oidc-readonly-HfgL2k password=A1b2C3d4-xxxxx dbname=blackpoint"
```

### Shell Aliases

```bash
# Add to ~/.bashrc
alias vlogin='vault login -method=oidc'

vdb() {
  local db=$1
  local access=${2:-readonly}
  eval $(vault read -format=json "database/creds/${db}-${access}" | \
    jq -r '.data | "export PGUSER=\(.username) PGPASSWORD=\(.password)"')
  echo "Credentials set for ${db} (${access})"
}

# Usage:
# vdb blackpoint-dev           # readonly
# vdb blackpoint-dev readwrite # readwrite
# psql -h blackpoint-dev.ts.net -d blackpoint
```

## 5. Revocation Flow

```
Timeline:
─────────────────────────────────────────────────────────────
T=0h:  User gets credentials (24h TTL)
T=1h:  Admin removes db-app-blackpoint from user in Auth0
T=2h:  User tries to get new credentials → DENIED
T=24h: Old credentials expire → Complete access loss
─────────────────────────────────────────────────────────────
```

## 6. Comparison: PKI vs Database Secrets

| Aspect | PKI Certificates | Database Secrets |
|--------|------------------|------------------|
| **TTL** | 1 year | 24 hours |
| **Revocation** | Complex (CRL) | Automatic |
| **Role change** | No effect | Next request denied |
| **UX** | Set once | Daily refresh |
| **IDE support** | Native SSL | Need wrapper |
