# Vault PKI Database Access

Централизованный доступ к базам данных через mTLS сертификаты с Auth0 SSO.

## Цели

- Certificate-based доступ к БД (без паролей)
- Auth0 SSO → Vault → Certificate → Database
- RBAC через Auth0 roles → Vault policies
- Long-lived сертификаты (до 1 года)
- Поддержка любых DB с mTLS (PostgreSQL, MySQL, MongoDB, Redis)

## Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                         Auth0                                    │
│  Roles: db-admin, db-readonly, db-app-*, db-env-*               │
└─────────────────────────┬───────────────────────────────────────┘
                          │ OIDC
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Vault                                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │ OIDC Auth   │───▶│ Policies    │───▶│ PKI Engine          │ │
│  │ (Auth0)     │    │ (per role)  │    │ - Root CA           │ │
│  └─────────────┘    └─────────────┘    │ - Intermediate CA   │ │
│                                         │ - Issue certs       │ │
│                                         └─────────────────────┘ │
└─────────────────────────┬───────────────────────────────────────┘
                          │ X.509 Certificates
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Tailscale Network                             │
└─────────────────────────┬───────────────────────────────────────┘
                          │ mTLS
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Databases                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ CNPG     │  │ MySQL    │  │ MongoDB  │  │ Redis    │       │
│  │ (PG)     │  │          │  │          │  │          │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## RBAC Flow

```
Auth0 Roles                    Vault Policy              PKI Role              DB Access
────────────────────────────────────────────────────────────────────────────────────────
db-readonly                 →  pki-readonly           →  readonly cert      →  SELECT only
db-readwrite                →  pki-readwrite          →  readwrite cert     →  CRUD
db-app-blackpoint           →  pki-blackpoint         →  blackpoint DBs     →  specific app
db-env-dev                  →  pki-dev                →  dev environment    →  dev DBs only
db-admin                    →  pki-admin              →  any cert           →  ALL PRIVILEGES
```

## Компоненты

| Компонент | Назначение |
|-----------|------------|
| Vault | PKI CA + OIDC auth |
| Auth0 | Identity provider, roles |
| Tailscale | Network security layer |
| CNPG | PostgreSQL with mTLS |

## Документы

1. [01-vault-install.md](01-vault-install.md) - Установка Vault в K8s
2. [02-pki-engine.md](02-pki-engine.md) - Настройка PKI engine
3. [03-auth0-oidc.md](03-auth0-oidc.md) - Интеграция с Auth0
4. [04-policies.md](04-policies.md) - Vault policies для RBAC
5. [05-database-config.md](05-database-config.md) - Настройка баз данных
6. [06-tailscale-expose.md](06-tailscale-expose.md) - Expose через Tailscale
7. [07-client-workflow.md](07-client-workflow.md) - Developer workflow

## Prerequisites

- [x] K8s cluster (k3s)
- [x] CloudNativePG PostgreSQL clusters
- [x] Auth0 tenant с ролями
- [x] Tailscale operator
- [ ] Vault

## Auth0 Roles (уже созданы)

```
# Permission roles
db-readonly       - Database read-only access
db-readwrite      - Database read-write access

# App roles
db-app-blackpoint - Access to Blackpoint databases
db-app-notifier   - Access to Notifier databases

# Environment roles
db-env-dev        - Access to dev environment
db-env-prd        - Access to prd environment

# Admin
db-admin          - Full database admin access
```
