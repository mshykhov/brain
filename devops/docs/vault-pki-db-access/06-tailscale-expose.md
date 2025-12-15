# Expose Databases via Tailscale

## Architecture

```
deploy/databases/blackpoint-api/postgres/main.yaml
  └── tailscale.enabled: true
        │
        ▼
ApplicationSet (postgres-clusters)
  └── scans databases/*/postgres/*.yaml
  └── renders 2 charts per database:
        │
        ├── CloudNativePG Cluster chart
        │     └── creates PostgreSQL cluster
        │
        └── tailscale-service chart (if tailscale.enabled)
              └── creates LoadBalancer Service via ProxyGroup
                    │
                    ▼
              Tailscale Operator + ProxyGroup (ingress-proxies)
                └── exposes to tailnet: {hostname}-{env}.trout-paradise.ts.net:5432
```

## 1. Database Configuration (Decentralized)

Добавить `tailscale:` секцию в конфиг БД:

`deploy/databases/blackpoint-api/postgres/main.yaml`:

```yaml
cluster:
  instances: 1
  storage:
    size: 5Gi
  initdb:
    database: blackpoint
    owner: blackpoint

# Tailscale exposure
tailscale:
  enabled: true
  hostname: blackpoint-db  # => blackpoint-db-{env}.trout-paradise.ts.net:5432
```

## 2. How It Works

1. **ApplicationSet** `postgres-clusters` сканирует `databases/*/postgres/*.yaml`
2. Для каждой БД создаёт Application с **двумя источниками**:
   - CloudNativePG Cluster chart → создаёт PostgreSQL кластер
   - tailscale-service chart → создаёт LoadBalancer Service (если `tailscale.enabled: true`)
3. **Helm chart** рендерит LoadBalancer Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    tailscale.com/proxy-group: ingress-proxies  # HA via ProxyGroup
    tailscale.com/hostname: blackpoint-db-dev
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    cnpg.io/cluster: blackpoint-api-main-db-dev-cluster
    role: primary
  ports:
    - port: 5432
```

4. **Tailscale Operator** видит Service и создаёт proxy через ProxyGroup
5. Доступ: `blackpoint-db-dev.trout-paradise.ts.net:5432`

## 3. Current Databases

| Database | Env | Hostname | Access |
|----------|-----|----------|--------|
| blackpoint-api | dev | `blackpoint-db-dev` | `blackpoint-db-dev.trout-paradise.ts.net:5432` |
| blackpoint-api | prd | `blackpoint-db-prd` | `blackpoint-db-prd.trout-paradise.ts.net:5432` |
| notifier | dev | `notifier-db-dev` | `notifier-db-dev.trout-paradise.ts.net:5432` |
| notifier | prd | `notifier-db-prd` | `notifier-db-prd.trout-paradise.ts.net:5432` |

**Note:** Hostname = `{tailscale.hostname}-{env}` (env suffix always added)

## 4. Tailscale ACLs

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:developer"],
      "dst": ["tag:k8s:5432"]
    },
    {
      "action": "accept",
      "src": ["tag:admin"],
      "dst": ["tag:k8s:*"]
    }
  ],
  "tagOwners": {
    "tag:developer": ["autogroup:admin"],
    "tag:admin": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  }
}
```

## 5. Connection Examples

### Get Credentials from Vault

```bash
# Login (once per 7 days)
vault login -method=oidc

# Get dynamic credentials (once per day)
vault read database/creds/blackpoint-dev-readonly
# username    v-oidc-readonly-HfgL2k
# password    A1b2C3d4-xxxxx
# ttl         24h
```

### psql

```bash
psql "host=blackpoint-db-dev.trout-paradise.ts.net \
      port=5432 \
      dbname=blackpoint \
      user=v-oidc-readonly-HfgL2k \
      password=A1b2C3d4-xxxxx \
      sslmode=require"
```

### DataGrip / IntelliJ

```
Host: blackpoint-db-dev.trout-paradise.ts.net
Port: 5432
Database: blackpoint
User: <from vault read>
Password: <from vault read>
SSL Mode: require
```

## 6. Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Tailscale Network                                      │
│ - Only tailnet members can reach database ports                 │
│ - Tailscale ACLs control which users/tags can connect           │
│ - ProxyGroup provides HA (2 replicas)                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: Vault Dynamic Credentials                              │
│ - User authenticates via Vault OIDC (Auth0 SSO)                 │
│ - Auth0 roles determine database access (3D cross-product)      │
│ - Vault generates temporary username/password (24h TTL)         │
│ - Role change in Auth0 → immediate denial of new credentials    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: PostgreSQL Dynamic Users                               │
│ - Vault creates temporary DB user: v-oidc-readonly-HfgL2k       │
│ - User has specific GRANT permissions based on role             │
│ - Auto-dropped when TTL expires                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 7. Files Reference

| File | Purpose |
|------|---------|
| `infrastructure/charts/tailscale-service/` | Helm chart for TS LoadBalancer |
| `infrastructure/apps/templates/data/postgres-clusters.yaml` | ApplicationSet (includes tailscale-service as 2nd source) |
| `deploy/databases/*/postgres/main.yaml` | Database configs with `tailscale:` section |

## Next Steps

→ [07-client-workflow.md](07-client-workflow.md)
