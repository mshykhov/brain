# Phase 12: Teleport Database Access

Централизованный доступ к PostgreSQL через Teleport с Auth0 SSO.

## Цели

- Passwordless доступ к БД через SSO (Auth0)
- RBAC: readonly / readwrite роли
- Query audit logging
- Подключение из IntelliJ IDEA через `tsh proxy db`

## Архитектура

```
┌─────────────┐     ┌──────────────┐     ┌─────────────────┐
│  IntelliJ   │────▶│   Teleport   │────▶│  CloudNativePG  │
│  IDEA       │     │   Cluster    │     │  PostgreSQL     │
└─────────────┘     └──────┬───────┘     └─────────────────┘
                           │
                    ┌──────▼───────┐
                    │    Auth0     │
                    │    SSO       │
                    └──────────────┘
```

## Компоненты

| Компонент | Назначение |
|-----------|------------|
| teleport-cluster | Auth + Proxy services |
| teleport-kube-agent | Database agent для CNPG |
| Auth0 OIDC connector | SSO интеграция |
| Teleport roles | RBAC для db_users/db_names |

## Документы

1. [01-teleport-cluster.md](01-teleport-cluster.md) - Установка Teleport в K8s
2. [02-auth0-oidc.md](02-auth0-oidc.md) - Интеграция с Auth0
3. [03-database-agent.md](03-database-agent.md) - Enrollment PostgreSQL
4. [04-rbac-roles.md](04-rbac-roles.md) - Настройка ролей
5. [05-client-setup.md](05-client-setup.md) - Настройка tsh и IDEA

## Prerequisites

- [x] K8s cluster (k3s)
- [x] CloudNativePG PostgreSQL clusters
- [x] Auth0 tenant
- [x] Tailscale operator
- [ ] DNS record для Teleport (teleport.gaynance.com)
