# Phase 12: Vault Database Access

Доступ к PostgreSQL через Vault Database Secrets Engine + Auth0 SSO.

## Архитектура

```
Developer → Tailscale VPN → Vault UI (Auth0 SSO) → Database Credentials → PostgreSQL
```

## Как это работает

1. Developer заходит в Vault UI через Tailscale
2. Vault аутентифицирует через Auth0 (SSO)
3. Auth0 роль определяет доступные Vault policies
4. Developer запрашивает credentials через UI/CLI
5. Vault генерирует временный username/password
6. Developer подключается к PostgreSQL с этими credentials

## Компоненты

| Компонент | Назначение |
|-----------|------------|
| Vault | Database Secrets Engine + OIDC auth |
| Auth0 | SSO + роли (db:{app}:{env}:{access}) |
| CNPG | PostgreSQL clusters |
| Tailscale | VPN доступ к Vault и PostgreSQL |
| Doppler | Vault secrets (root token, unseal key) |

## Уровни доступа

| Auth0 Role | Vault Policy | TTL | Permissions |
|------------|--------------|-----|-------------|
| db:{app}:{env}:readonly | database-{app}-{env}-readonly | 24-72h | SELECT |
| db:{app}:{env}:readwrite | database-{app}-{env}-readwrite | 24-72h | CRUD |
| db:{app}:{env}:admin | database-{app}-{env}-admin | 8-24h | ALL |

## Документы

1. [01-vault-setup.md](01-vault-setup.md) - Установка и конфигурация Vault
2. [02-auth0-oidc.md](02-auth0-oidc.md) - Интеграция с Auth0
3. [03-rbac-roles.md](03-rbac-roles.md) - Роли и policies
4. [04-client-setup.md](04-client-setup.md) - Подключение из IntelliJ

## URLs

- Vault UI: `https://vault.{tailnet}.ts.net`
- PostgreSQL: `{cluster}-rw.{namespace}.svc` через Tailscale
