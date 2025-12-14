# Vault PKI Database Access

Централизованный доступ к базам данных через mTLS сертификаты с Auth0 SSO.

## Статус

- [x] Vault установлен (standalone mode)
- [x] PKI Engine настроен (Root + Intermediate CA)
- [x] Auth0 OIDC настроен
- [x] CNPG интеграция работает
- [ ] Vault OIDC login (email claim issue)
- [ ] Client workflow тестирование

## Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                         Auth0                                    │
│  Roles: db-admin, db-readonly, db-readwrite                     │
└─────────────────────────┬───────────────────────────────────────┘
                          │ OIDC
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Vault                                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │ OIDC Auth   │───▶│ Policies    │───▶│ PKI Engine          │ │
│  │ (Auth0)     │    │ (per role)  │    │ - Root CA (10y)     │ │
│  └─────────────┘    └─────────────┘    │ - Intermediate (5y) │ │
│                                         │ - Issue certs (3mo) │ │
│                                         └─────────────────────┘ │
└─────────────────────────┬───────────────────────────────────────┘
                          │ X.509 Certificates
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Tailscale Network                             │
│                    (100.64.0.0/10)                               │
└─────────────────────────┬───────────────────────────────────────┘
                          │ mTLS (cert auth)
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                CloudNativePG (PostgreSQL)                        │
│  pg_hba.conf:                                                   │
│  - hostssl all all 10.42.0.0/16 scram-sha-256  (apps)          │
│  - hostssl all all 100.64.0.0/10 cert          (developers)    │
└─────────────────────────────────────────────────────────────────┘
```

## RBAC Flow

```
Auth0 Role       →  Vault Policy    →  PKI Role      →  Can Issue Certs
─────────────────────────────────────────────────────────────────────────
db-admin         →  pki-admin       →  db-admin      →  any cert
db-readonly      →  pki-readonly    →  db-readonly   →  readonly certs
db-readwrite     →  pki-readwrite   →  db-readwrite  →  readwrite certs
```

## Компоненты

| Компонент | Назначение | Статус |
|-----------|------------|--------|
| Vault | PKI CA + OIDC auth | ✅ |
| vault-config chart | GitOps конфигурация Vault | ✅ |
| Auth0 | SSO + роли | ✅ |
| Doppler | Secrets distribution | ✅ |
| ClusterExternalSecret | Распространение CA/certs | ✅ |
| CNPG | PostgreSQL с cert auth | ✅ |
| Tailscale | Network access | ✅ |

## Secrets в Doppler (shared)

| Key | Описание |
|-----|----------|
| `VAULT_ROOT_TOKEN` | Root token для Vault |
| `VAULT_UNSEAL_KEY` | Unseal key (1 of 1) |
| `VAULT_OIDC_CLIENT_SECRET` | Auth0 client secret |
| `VAULT_CA_CERT` | Intermediate CA certificate |
| `CNPG_REPLICATION_TLS_CRT` | streaming_replica certificate |
| `CNPG_REPLICATION_TLS_KEY` | streaming_replica private key |

## Документы

1. [01-vault-install.md](01-vault-install.md) - Установка Vault
2. [02-pki-engine.md](02-pki-engine.md) - PKI Engine (GitOps)
3. [03-auth0-oidc.md](03-auth0-oidc.md) - Auth0 интеграция
4. [04-policies.md](04-policies.md) - Vault policies
5. [05-database-config.md](05-database-config.md) - CNPG конфигурация
6. [06-tailscale-expose.md](06-tailscale-expose.md) - Tailscale exposure
7. [07-client-workflow.md](07-client-workflow.md) - Developer workflow
