# CNPG Certificate Authentication

## Архитектура

```
Vault PKI (Intermediate CA)
        │
        ├── vault-ca secret (ca.crt only)
        │   └── Используется CNPG для верификации client certs
        │
        └── cnpg-replication-tls secret (tls.crt + tls.key)
            └── Client cert для streaming_replica user
```

## Secrets в Doppler (shared)

| Key | Описание | Команда |
|-----|----------|---------|
| `VAULT_CA_CERT` | CA certificate | `vault read -field=certificate pki_int/cert/ca` |
| `CNPG_REPLICATION_TLS_CRT` | Replication cert | См. ниже |
| `CNPG_REPLICATION_TLS_KEY` | Replication key | См. ниже |

## Генерация Replication Certificate

```bash
# Из Vault pod с root token
vault write -format=json pki_int/issue/db-admin \
  common_name=streaming_replica \
  ttl=2190h

# Скопировать из вывода:
# - certificate → CNPG_REPLICATION_TLS_CRT
# - private_key → CNPG_REPLICATION_TLS_KEY
```

## ClusterExternalSecrets

Распространяют secrets во все namespaces с `tier: application`:

```yaml
# vault-ca → ca.crt
# cnpg-replication-tls → tls.crt, tls.key (kubernetes.io/tls type)
```

## CNPG Cluster Config

```yaml
# postgres-defaults.yaml
cluster:
  certificates:
    clientCASecret: vault-ca
    replicationTLSSecret: cnpg-replication-tls

  postgresql:
    pg_hba:
      # Apps (pod network) - password
      - hostssl all all 10.42.0.0/16 scram-sha-256
      # Developers (Tailscale) - certificate
      - hostssl all all 100.64.0.0/10 cert
```

## Почему нужен replicationTLSSecret?

По [документации CNPG](https://cloudnative-pg.io/documentation/current/certificates/):

> If `replicationTLSSecret` is not defined, `ClientCASecret` must provide also `ca.key`

Мы не хотим распространять private key CA, поэтому предоставляем готовый client cert для replication.

## Проверка

```bash
# Secrets распространены
kubectl get secrets -A | grep -E 'vault-ca|cnpg-replication'

# CNPG cluster status
kubectl get clusters.postgresql.cnpg.io -A
```
