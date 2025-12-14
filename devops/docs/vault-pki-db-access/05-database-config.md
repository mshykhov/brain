# Database Configuration for Certificate Auth

## 1. Architecture

```
Vault PKI (Intermediate CA)
        │
        ├── vault-ca secret (ca.crt only)
        │   └── Used by CNPG for client certificate verification
        │
        └── cnpg-replication-tls secret (tls.crt + tls.key)
            └── Client cert for streaming_replica user
```

## 2. Secrets in Doppler (shared)

| Key | Description | Command |
|-----|-------------|---------|
| `VAULT_CA_CERT` | Intermediate CA certificate | `vault read -field=certificate pki_int/cert/ca` |
| `CNPG_REPLICATION_TLS_CRT` | Replication certificate | See below |
| `CNPG_REPLICATION_TLS_KEY` | Replication private key | See below |

## 3. Generate Replication Certificate

```bash
# Connect to Vault with root token
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault write -format=json pki_int/issue/db-admin common_name=streaming_replica ttl=2190h"

# Copy from output:
# - certificate → CNPG_REPLICATION_TLS_CRT
# - private_key → CNPG_REPLICATION_TLS_KEY
```

## 4. ClusterExternalSecrets

### vault-ca

`infrastructure/charts/credentials/templates/vault-ca.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterExternalSecret
metadata:
  name: vault-ca
spec:
  externalSecretName: vault-ca
  namespaceSelectors:
    - matchLabels:
        tier: application
  refreshTime: 5m
  externalSecretSpec:
    secretStoreRef:
      name: doppler-shared
      kind: ClusterSecretStore
    target:
      name: vault-ca
      template:
        type: Opaque
        data:
          ca.crt: "{{ .caCert }}"
    data:
      - secretKey: caCert
        remoteRef:
          key: VAULT_CA_CERT
```

### cnpg-replication-tls

`infrastructure/charts/credentials/templates/cnpg-replication-tls.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterExternalSecret
metadata:
  name: cnpg-replication-tls
spec:
  externalSecretName: cnpg-replication-tls
  namespaceSelectors:
    - matchLabels:
        tier: application
  refreshTime: 5m
  externalSecretSpec:
    secretStoreRef:
      name: doppler-shared
      kind: ClusterSecretStore
    target:
      name: cnpg-replication-tls
      template:
        type: kubernetes.io/tls
        data:
          tls.crt: "{{ .tlsCrt }}"
          tls.key: "{{ .tlsKey }}"
    data:
      - secretKey: tlsCrt
        remoteRef:
          key: CNPG_REPLICATION_TLS_CRT
      - secretKey: tlsKey
        remoteRef:
          key: CNPG_REPLICATION_TLS_KEY
```

## 5. CNPG Cluster Configuration

`infrastructure/helm-values/data/postgres-dev-defaults.yaml`:

```yaml
cluster:
  # Certificate authentication with Vault CA
  certificates:
    clientCASecret: vault-ca
    replicationTLSSecret: cnpg-replication-tls

  postgresql:
    # pg_hba.conf authentication rules
    pg_hba:
      # Apps inside cluster (pod network) - password auth
      - hostssl all all 10.42.0.0/16 scram-sha-256
      # Developers via Tailscale - certificate auth
      - hostssl all all 100.64.0.0/10 cert
```

## 6. Why replicationTLSSecret?

По [документации CNPG](https://cloudnative-pg.io/documentation/current/certificates/):

> If `replicationTLSSecret` is not defined, `ClientCASecret` must provide also `ca.key`

Мы не хотим распространять private key CA, поэтому предоставляем готовый client cert для streaming_replica user.

## 7. Verify Configuration

```bash
# Check secrets are distributed
ssh ovh-ts "sudo kubectl get secrets -A | grep -E 'vault-ca|cnpg-replication'"

# Check CNPG clusters status
ssh ovh-ts "sudo kubectl get clusters.postgresql.cnpg.io -A"

# Should show: Cluster in healthy state
```

## 8. PostgreSQL Users

Users для certificate auth создаются без password. CN сертификата = username.

```sql
-- User for readonly access (CN: readonly@domain.com maps to this)
CREATE ROLE readonly_user WITH LOGIN;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;

-- User for readwrite access
CREATE ROLE readwrite_user WITH LOGIN;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO readwrite_user;
```

## Next Steps

→ [06-tailscale-expose.md](06-tailscale-expose.md)
