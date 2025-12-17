# RBAC Roles

## Архитектура

```
Auth0 Role                → Vault External Group      → Vault Policy
─────────────────────────────────────────────────────────────────────
db:blackpoint:dev:readonly → db:blackpoint:dev:readonly → database-blackpoint-dev-readonly
db:blackpoint:prd:admin    → db:blackpoint:prd:admin    → database-blackpoint-prd-admin
```

## Access Levels

| Level | TTL | PostgreSQL Permissions |
|-------|-----|------------------------|
| readonly | 24-72h | SELECT |
| readwrite | 24-72h | SELECT, INSERT, UPDATE, DELETE |
| admin | 8-24h | ALL PRIVILEGES |

## Auto-generated Policies

vault-config автоматически создаёт policies из `database.databases`:

```hcl
# database-blackpoint-dev-readonly
path "database/creds/blackpoint-dev-readonly" {
  capabilities = ["read"]
}

# database-blackpoint-dev-readwrite (включает readonly)
path "database/creds/blackpoint-dev-readwrite" {
  capabilities = ["read"]
}
path "database/creds/blackpoint-dev-readonly" {
  capabilities = ["read"]
}

# database-blackpoint-dev-admin (все роли)
path "database/creds/blackpoint-dev-*" {
  capabilities = ["read"]
}
```

## Auto-generated Groups

External groups автоматически связывают Auth0 роли с Vault policies:

| Auth0 Role | Vault Policy |
|------------|--------------|
| db:blackpoint:dev:readonly | database-blackpoint-dev-readonly |
| db:blackpoint:dev:readwrite | database-blackpoint-dev-readwrite |
| db:blackpoint:dev:admin | database-blackpoint-dev-admin |

## Добавление нового пользователя

1. Auth0 → **User Management** → Users → выбрать пользователя
2. **Roles** → Assign Roles
3. Выбрать нужные роли (например, `db:blackpoint:dev:readonly`)
4. Пользователь получит доступ при следующем логине в Vault

## Проверка прав

```bash
# В Vault UI: правый верхний угол показывает assigned policies

# Или через CLI
vault token lookup
```
