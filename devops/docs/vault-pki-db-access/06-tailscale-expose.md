# Expose Databases via Tailscale

## 1. Expose Vault UI

### Add to protected-services

`infrastructure/charts/protected-services/values.yaml`:

```yaml
services:
  vault:
    enabled: true
    direct: true
    namespace: vault
    backend:
      name: vault
      port: 8200
```

Vault будет доступен по адресу: `https://vault.trout-paradise.ts.net`

## 2. Expose PostgreSQL (CNPG)

### Option A: Via Tailscale Service

`infrastructure/charts/protected-services/templates/tailscale-db.yaml`:

```yaml
{{- range $name, $db := .Values.databases }}
{{- if $db.enabled }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}-tailscale
  namespace: {{ $db.namespace }}
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: {{ $name }}
spec:
  type: ClusterIP
  selector:
    cnpg.io/cluster: {{ $db.cluster }}
    role: primary
  ports:
    - port: 5432
      targetPort: 5432
      protocol: TCP
{{- end }}
{{- end }}
```

### Database Configuration

`infrastructure/charts/protected-services/values.yaml`:

```yaml
databases:
  blackpoint-api-dev:
    enabled: true
    namespace: blackpoint-api-dev
    cluster: blackpoint-api-dev-cluster

  blackpoint-api-prd:
    enabled: true
    namespace: blackpoint-api-prd
    cluster: blackpoint-api-prd-cluster

  notifier-dev:
    enabled: true
    namespace: notifier-dev
    cluster: notifier-dev-cluster
```

### Result

Базы данных будут доступны:
- `blackpoint-api-dev.trout-paradise.ts.net:5432`
- `blackpoint-api-prd.trout-paradise.ts.net:5432`
- `notifier-dev.trout-paradise.ts.net:5432`

## 3. Tailscale ACLs

Добавить в Tailscale ACL для ограничения доступа:

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

## 4. Connection String Examples

### PostgreSQL

```bash
# Via Tailscale hostname
psql "host=blackpoint-api-dev.trout-paradise.ts.net \
      port=5432 \
      dbname=blackpoint \
      user=readonly_user \
      sslmode=verify-full \
      sslcert=~/.pg/client.crt \
      sslkey=~/.pg/client.key \
      sslrootcert=~/.pg/ca.crt"
```

### IntelliJ IDEA / DataGrip

```
Host: blackpoint-api-dev.trout-paradise.ts.net
Port: 5432
Database: blackpoint
User: readonly_user
SSL Mode: verify-full
CA File: ~/.pg/ca.crt
Client Certificate: ~/.pg/client.crt
Client Key: ~/.pg/client.key
```

## 5. Security Layers

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: Tailscale Network                                      │
│ - Only tailnet members can reach database ports                 │
│ - Tailscale ACLs control which users/tags can connect           │
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

## Next Steps

→ [07-client-workflow.md](07-client-workflow.md)
