# Client Setup

## Prerequisites

- Tailscale установлен и подключён к tailnet
- Auth0 аккаунт с назначенными ролями

## Получение Database Credentials

### Способ 1: Vault UI (рекомендуется)

1. Открыть `https://vault.{tailnet}.ts.net`
2. Sign in with OIDC → Auth0 SSO
3. **Secrets** → **database** → **creds** → выбрать роль (например, `blackpoint-dev-readonly`)
4. **Generate** → скопировать username и password

### Способ 2: Vault CLI

```bash
# Установка
# macOS: brew install hashicorp/tap/vault
# Windows: scoop install vault

# Login
export VAULT_ADDR=https://vault.{tailnet}.ts.net
vault login -method=oidc

# Получить credentials
vault read database/creds/blackpoint-dev-readonly

# Output:
# username    v-oidc-blackpoint-dev-readonly-xxx
# password    xxx-xxx-xxx
# ttl         24h
```

## Подключение к PostgreSQL

### IntelliJ IDEA / DataGrip

1. **Database** → **+** → **Data Source** → **PostgreSQL**
2. Connection:
   - Host: `blackpoint-api-main-db-dev-cluster-rw.blackpoint-api-dev.svc` (через Tailscale)
   - Port: `5432`
   - Database: `blackpoint`
   - User: `v-oidc-xxx` (из Vault)
   - Password: `xxx` (из Vault)
3. **Test Connection** → OK

### psql

```bash
psql "host=blackpoint-api-main-db-dev-cluster-rw.blackpoint-api-dev.svc \
      port=5432 \
      dbname=blackpoint \
      user=v-oidc-xxx \
      password=xxx"
```

## TTL и Renewal

- Credentials действительны 24-72h (зависит от роли)
- После истечения нужно получить новые через Vault
- Vault автоматически revoke старые credentials

## Troubleshooting

### "Permission denied" в Vault

```bash
# Проверить assigned policies
vault token lookup

# Убедиться что Auth0 роль назначена
# Auth0 → User Management → Users → Roles
```

### "Connection refused" к PostgreSQL

```bash
# Проверить Tailscale подключение
tailscale status

# Проверить что PostgreSQL доступен
nc -zv blackpoint-api-main-db-dev-cluster-rw.blackpoint-api-dev.svc 5432
```

### Credentials expired

Получить новые через Vault UI или CLI.
