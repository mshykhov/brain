# Auth0 Setup для oauth2-proxy

## Архитектура аутентификации

```
User → Tailscale VPN → Tailscale Ingress → NGINX → oauth2-proxy → Backend
                                              ↓
                                    auth-url check
                                              ↓
                                    Auth0 OIDC login
                                              ↓
                                    Groups from Action
```

**Важно:** Один Auth0 Application для oauth2-proxy защищает все сервисы (ArgoCD, Longhorn, Grafana). ArgoCD использует анонимный доступ за oauth2-proxy.

## Doppler Secrets

| Key | Где брать | Описание |
|-----|-----------|----------|
| `AUTH0_CLIENT_SECRET` | Auth0 → Applications | Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | `openssl rand -base64 32 \| head -c 32` | Шифрование cookies |
| `OAUTH2_PROXY_REDIS_PASSWORD` | `openssl rand -base64 32` | Пароль Redis |

**Non-secret values** (в `apps/values.yaml`):
- `auth0.domain` — Auth0 Domain
- `auth0.clientId` — Client ID

## 1. Создание Auth0 Tenant

1. [auth0.com](https://auth0.com) → Sign Up
2. Create tenant (e.g., `example-dev`)
3. Запомни domain: `example-dev.us.auth0.com`

## 2. Создание Application

1. Auth0 Dashboard → Applications → Create Application
2. Name: `oauth2-proxy`
3. Type: **Regular Web Application**
4. Click Create

## 3. Application Settings

### Basic Information
- **Name**: oauth2-proxy
- **Domain**: (auto-filled)

### Application URIs

**Allowed Callback URLs:**
```
https://argocd.<tailnet>.ts.net/oauth2/callback,
https://longhorn.<tailnet>.ts.net/oauth2/callback
```

**Allowed Logout URLs:**
```
https://argocd.<tailnet>.ts.net,
https://longhorn.<tailnet>.ts.net
```

**Allowed Web Origins:**
```
https://argocd.<tailnet>.ts.net,
https://longhorn.<tailnet>.ts.net
```

> Замени `<tailnet>` на твой tailnet (e.g., `tail876052`)

## 4. Auth0 Action для Groups

**КРИТИЧЕСКИ ВАЖНО:** Auth0 не включает groups/roles в ID token по умолчанию. Нужен Action.

### Создание Action

1. Auth0 Dashboard → Actions → Library → Build Custom
2. Name: `Add Groups to Token`
3. Trigger: `Login / Post Login`
4. Code:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://ns';
  if (event.authorization && event.authorization.roles) {
    api.idToken.setCustomClaim(`${namespace}/groups`, event.authorization.roles);
    api.accessToken.setCustomClaim(`${namespace}/groups`, event.authorization.roles);
  }
};
```

5. Deploy

### Добавление в Flow

1. Actions → Flows → Login
2. Drag `Add Groups to Token` в Flow
3. Apply

### Почему namespaced claim?

Auth0 требует namespace для custom claims. Без namespace (`https://ns/groups`) claim будет проигнорирован.

В oauth2-proxy это настраивается через:
```
oidc_groups_claim = "https://ns/groups"
```

## 5. Создание Roles

1. User Management → Roles → Create Role
2. Создай роли:
   - `infra-admins` — полный доступ ко всему
   - `argocd-admins` — доступ к ArgoCD
   - `longhorn-admins` — доступ к Longhorn

### Назначение ролей пользователям

1. User Management → Users → (выбери пользователя)
2. Roles → Assign Roles
3. Выбери нужные роли

## 6. Group-Based Authorization

Roles из Auth0 попадают в `https://ns/groups` claim. oauth2-proxy проверяет группы через query param:

```yaml
# В ingress annotations
nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy/oauth2/auth?allowed_groups=infra-admins,argocd-admins"
```

### Как это работает

1. User логинится через Auth0
2. Auth0 Action добавляет roles в `https://ns/groups`
3. oauth2-proxy получает groups из token
4. NGINX передаёт `allowed_groups` в auth-url
5. oauth2-proxy проверяет пересечение

## 7. Проверка

### Проверить token содержит groups

```bash
# Логи oauth2-proxy
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy

# Должно быть что-то вроде:
# groups: [infra-admins argocd-admins]
```

### Тестовый login

```bash
# Открой браузер
https://argocd.<tailnet>.ts.net

# Должен редиректить на Auth0
# После login → ArgoCD UI
```

### Проверить роли пользователя в Auth0

1. Auth0 Dashboard → User Management → Users
2. Выбери пользователя → Roles tab
3. Должны быть назначены роли

## Troubleshooting

### "Unable to verify OIDC token"

- Проверь `AUTH0_DOMAIN` без `https://` prefix
- Проверь что oauth2-proxy может достучаться до Auth0

### Groups пустые

1. Проверь что Action добавлен в Login Flow
2. Проверь что Action deployed
3. Проверь что у пользователя есть Roles
4. Проверь `oidc_groups_claim = "https://ns/groups"` в oauth2-proxy config

### 403 после login

- Groups не совпадают с `allowed_groups`
- Проверь роли пользователя в Auth0
- Проверь spelling групп (case-sensitive)

### Callback URL mismatch

- URL в Auth0 должны точно совпадать с hosts в ingress
- Включая протокол (`https://`) и путь (`/oauth2/callback`)

## Следующий шаг

[04-argocd-anonymous.md](04-argocd-anonymous.md) — настройка ArgoCD с анонимным доступом
