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
/**
 * Auth0 Post-Login Action: Compute Vault Database Roles
 *
 * Transforms modular Auth0 roles into Vault-compatible role format.
 *
 * Input roles (assigned in Auth0):
 *   - db-readonly, db-readwrite, db-admin (access levels)
 *   - db-app-{name} (database access, e.g., db-app-blackpoint)
 *   - db-env-{env} (environment access, e.g., db-env-dev)
 *
 * Output roles (sent to Vault):
 *   - db:{app}:{env}:{access} (e.g., db:blackpoint:dev:readonly)
 *
 * Configuration is in Vault: infrastructure/charts/vault-config/values.yaml
 */
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://vault';
  const roles = event.authorization?.roles || [];

  // Validation constants
  const VALID_ACCESS_LEVELS = ['readonly', 'readwrite', 'admin'];
  const VALID_ENVIRONMENTS = ['dev', 'prd'];

  console.log(`[Vault Roles] Processing user: ${event.user.email}`);
  console.log(`[Vault Roles] Input roles: ${JSON.stringify(roles)}`);

  // Extract and validate role categories
  const accessLevels = roles
    .filter(r => ['db-readonly', 'db-readwrite', 'db-admin'].includes(r))
    .map(r => r.replace('db-', ''));

  const apps = roles
    .filter(r => r.startsWith('db-app-'))
    .map(r => r.replace('db-app-', ''))
    .filter(app => {
      // Validate app name format (lowercase, alphanumeric, hyphens)
      const valid = /^[a-z][a-z0-9-]*$/.test(app);
      if (!valid) console.warn(`[Vault Roles] Invalid app name: ${app}`);
      return valid;
    });

  const envs = roles
    .filter(r => r.startsWith('db-env-'))
    .map(r => r.replace('db-env-', ''))
    .filter(env => {
      const valid = VALID_ENVIRONMENTS.includes(env);
      if (!valid) console.warn(`[Vault Roles] Invalid environment: ${env}`);
      return valid;
    });

  // Compute 3D cross-product: app × env × access
  const computedRoles = [];
  for (const app of apps) {
    for (const env of envs) {
      for (const access of accessLevels) {
        const role = `db:${app}:${env}:${access}`;
        computedRoles.push(role);
      }
    }
  }

  // Add non-db roles (infra-admins, argocd-admins, etc.)
  const otherRoles = roles.filter(r => !r.startsWith('db-'));
  const allRoles = [...computedRoles, ...otherRoles];

  console.log(`[Vault Roles] Computed roles: ${JSON.stringify(computedRoles)}`);
  console.log(`[Vault Roles] Total roles for Vault: ${allRoles.length}`);

  // Set claims on both ID token and access token
  api.idToken.setCustomClaim(`${namespace}/roles`, allRoles);
  api.accessToken.setCustomClaim(`${namespace}/roles`, allRoles);
};
```

### Validation Rules

| Component | Format | Example |
|-----------|--------|---------|
| App name | `^[a-z][a-z0-9-]*$` | `blackpoint`, `my-api` |
| Environment | `dev` or `prd` | `dev` |
| Access level | `readonly`, `readwrite`, `admin` | `readonly` |

### Debugging

View logs in **Auth0 Dashboard** → **Monitoring** → **Logs** → filter by user email.

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

## 6. Adding New Database (GitOps)

Only **3 steps** required! Connections, roles, policies, and groups are **auto-generated**.

### Step 1: Add to values.yaml

File: `infrastructure/charts/vault-config/values.yaml`

```yaml
database:
  databases:
    # Existing databases...
    blackpoint:
      dev:
        # ...

    # NEW DATABASE - just add here (10 lines)
    notifier:
      dev:
        host: "notifier-main-db-dev-cluster-rw.notifier-dev.svc"
        port: 5432
        database: notifier
        sslmode: require
        username: "postgres"
        secretRef:
          namespace: notifier-dev
          name: notifier-main-db-dev-cluster-superuser
          key: password
        access: [readonly, readwrite]  # Choose access levels
```

### Step 2: Add Auth0 Role

In **Auth0 Dashboard** → **User Management** → **Roles**:
1. Create role: `db-app-notifier`
2. Assign to users who need access

### Step 3: Deploy

```bash
git add -A && git commit -m "feat(vault): add notifier-dev database" && git push
# ArgoCD syncs automatically
```

### What Gets Auto-Generated

From 10 lines of config, the system creates:

| Resource | Generated |
|----------|-----------|
| Connection | `notifier-dev` |
| Roles | `notifier-dev-readonly`, `notifier-dev-readwrite` |
| Policies | `database-notifier-dev-readonly`, `database-notifier-dev-readwrite` |
| External Groups | `db:notifier:dev:readonly`, `db:notifier:dev:readwrite` |
| RBAC | Role/RoleBinding in `notifier-dev` namespace |

### Access Templates

Access levels are defined once in `database.accessTemplates`:

| Level | TTL | Permissions |
|-------|-----|-------------|
| `readonly` | 24h | SELECT |
| `readwrite` | 24h | SELECT, INSERT, UPDATE, DELETE |
| `admin` | 8h | ALL PRIVILEGES |

## 7. Comparison: PKI vs Database Secrets

| Aspect | PKI Certificates | Database Secrets |
|--------|------------------|------------------|
| **TTL** | 1 year | 24 hours |
| **Revocation** | Complex (CRL) | Automatic |
| **Role change** | No effect | Next request denied |
| **UX** | Set once | Daily refresh |
| **IDE support** | Native SSL | Need wrapper |
