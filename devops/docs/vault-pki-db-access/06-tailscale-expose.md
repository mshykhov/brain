# Expose Databases via Tailscale

## Architecture

```
deploy/databases/blackpoint-api/postgres/main.yaml
  └── tailscale.enabled: true
        │
        ▼
ApplicationSet (tailscale-database-services)
  └── scans databases/*/postgres/*.yaml
        │
        ▼
Helm Chart (tailscale-service)
  └── creates LoadBalancer Service via ProxyGroup
        │
        ▼
Tailscale Operator + ProxyGroup (ingress-proxies)
  └── exposes to tailnet: {hostname}.trout-paradise.ts.net:5432
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
  hostname: blackpoint-db  # => blackpoint-db.trout-paradise.ts.net:5432
```

## 2. How It Works

1. **ApplicationSet** сканирует `databases/*/postgres/*.yaml`
2. Если `tailscale.enabled: true` → создаёт Application
3. **Helm chart** рендерит LoadBalancer Service:

```yaml
apiVersion: v1
kind: Service
metadata:
  annotations:
    tailscale.com/proxy-group: ingress-proxies  # HA via ProxyGroup
    tailscale.com/hostname: blackpoint-db
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    cnpg.io/cluster: blackpoint-api-main-db-dev-cluster
    role: primary
  ports:
    - port: 5432
```

4. **Tailscale Operator** видит Service и создаёт proxy
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

### psql

```bash
psql "host=blackpoint-db-dev.trout-paradise.ts.net \
      port=5432 \
      dbname=blackpoint \
      user=myuser@company.com \
      sslmode=verify-full \
      sslcert=~/.pg/client.crt \
      sslkey=~/.pg/client.key \
      sslrootcert=~/.pg/ca.crt"
```

### DataGrip / IntelliJ

```
Host: blackpoint-db-dev.trout-paradise.ts.net
Port: 5432
Database: blackpoint
User: myuser@company.com
SSL Mode: verify-full
CA File: ~/.pg/ca.crt
Client Certificate: ~/.pg/client.crt
Client Key: ~/.pg/client.key
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
│ Layer 2: mTLS Certificate                                       │
│ - Client must present valid certificate from Vault CA           │
│ - Certificate CN maps to database user                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: PostgreSQL RBAC                                        │
│ - Database user has specific GRANT permissions                  │
│ - readonly_user: SELECT only                                    │
│ - readwrite_user: SELECT, INSERT, UPDATE, DELETE                │
└─────────────────────────────────────────────────────────────────┘
```

## 7. Files Reference

| File | Purpose |
|------|---------|
| `infrastructure/charts/tailscale-service/` | Helm chart for TS LoadBalancer |
| `infrastructure/apps/templates/data/tailscale-database-services.yaml` | ApplicationSet |
| `deploy/databases/*/postgres/main.yaml` | Database configs with `tailscale:` section |

## Next Steps

→ [07-client-workflow.md](07-client-workflow.md)
