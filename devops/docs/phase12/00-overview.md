# Phase 12: Vault PKI Database Access

Централизованный доступ к PostgreSQL через Vault PKI + Auth0 SSO.

## Цели

- Certificate-based доступ к БД через SSO (Auth0)
- RBAC: db-admin / db-readonly / db-readwrite роли
- Подключение из IntelliJ IDEA через Tailscale

## Архитектура

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  IntelliJ   │────▶│    Vault     │────▶│  CloudNativePG  │
│  IDEA       │     │  PKI + OIDC  │     │  PostgreSQL     │
└─────────────┘     └──────┬───────┘     └─────────────────┘
      │                    │
      │             ┌──────▼───────┐
      │             │    Auth0     │
      │             │    SSO       │
      └─────────────┴──────────────┘
            Tailscale VPN
```

## Компоненты

| Компонент | Назначение |
|-----------|------------|
| HashiCorp Vault | PKI CA + OIDC auth |
| Auth0 | SSO + роли (db-admin, db-readonly, db-readwrite) |
| CNPG | PostgreSQL с cert auth |
| Tailscale | Secure access |
| Doppler | Secrets distribution |

## Документы

1. [01-vault-setup.md](01-vault-setup.md) - Установка Vault в K8s
2. [02-auth0-oidc.md](02-auth0-oidc.md) - Интеграция с Auth0
3. [03-cnpg-certificates.md](03-cnpg-certificates.md) - Настройка CNPG
4. [04-rbac-roles.md](04-rbac-roles.md) - Vault policies и Auth0 roles
5. [05-client-setup.md](05-client-setup.md) - Настройка клиента

## Prerequisites

- [x] K8s cluster (k3s)
- [x] CloudNativePG PostgreSQL clusters
- [x] Auth0 tenant
- [x] Tailscale operator
- [x] Doppler + ExternalSecrets

## Access

- Vault UI: `https://vault.trout-paradise.ts.net`
- PostgreSQL: через Tailscale + client certificate
