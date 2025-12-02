# Auth0 SPA Configuration

## Overview

Auth0 Single Page Application для example-ui. Отличается от oauth2-proxy (Regular Web App).

**Важно:** Dev Keys warning означает использование тестовых ключей Auth0 для Social Connections. Если не используешь Google/Facebook login - просто отключи их в Auth0 Dashboard → Authentication → Social.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        example-ui (SPA)                          │
│                                                                  │
│  1. User clicks "Login"                                         │
│  2. Redirect to Auth0 Universal Login                           │
│  3. Auth0 returns tokens to callback URL                        │
│  4. UI stores tokens in memory                                  │
│  5. UI sends JWT in Authorization header to API                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        example-api (Resource Server)             │
│                                                                  │
│  1. Receives request with Authorization: Bearer <JWT>           │
│  2. Validates JWT signature with Auth0 JWKS                     │
│  3. Extracts user info and roles from token                     │
│  4. Returns data based on permissions                           │
└─────────────────────────────────────────────────────────────────┘
```

## Create Auth0 SPA Application

### 1. Create Application

1. Auth0 Dashboard → Applications → Create Application
2. **Name**: `example-ui-dev` (или `example-ui-prd`)
3. **Type**: Single Page Application
4. Click Create

### 2. Configure URLs

Settings → Application URIs:

**DEV:**

| Field | Value |
|-------|-------|
| Allowed Callback URLs | `http://localhost:5173, https://example-ui-dev.tail876052.ts.net` |
| Allowed Logout URLs | `http://localhost:5173, https://example-ui-dev.tail876052.ts.net` |
| Allowed Web Origins | `http://localhost:5173, https://example-ui-dev.tail876052.ts.net` |

**PRD:**

| Field | Value |
|-------|-------|
| Allowed Callback URLs | `https://app.untrustedonline.org` |
| Allowed Logout URLs | `https://app.untrustedonline.org` |
| Allowed Web Origins | `https://app.untrustedonline.org` |

### 3. Get Credentials

Copy from Application Settings:
- **Domain**: `dev-tgrsoxiakeqdr1gg.us.auth0.com`
- **Client ID**: (separate for dev/prd)

**Note:** SPA не использует Client Secret (public client).

## API Configuration

### 1. Create API (Resource Server)

1. Auth0 Dashboard → Applications → APIs → Create API
2. **Name**: `example-api`
3. **Identifier** (Audience): `https://api.untrustedonline.org`
4. **Signing Algorithm**: RS256

### 2. Enable RBAC (Optional)

APIs → example-api → Settings:
- Enable RBAC: ON
- Add Permissions in the Access Token: ON

## Groups/Roles in Token

Auth0 Action для добавления групп в token (уже настроено для oauth2-proxy, работает и для SPA):

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://ns';
  if (event.authorization && event.authorization.roles) {
    api.idToken.setCustomClaim(`${namespace}/groups`, event.authorization.roles);
    api.accessToken.setCustomClaim(`${namespace}/groups`, event.authorization.roles);
  }
};
```

## Environment Variables

### example-ui

```yaml
# values.yaml (base)
env:
  - name: AUTH0_DOMAIN
    value: "dev-tgrsoxiakeqdr1gg.us.auth0.com"
  - name: AUTH0_AUDIENCE
    value: "https://api.untrustedonline.org"

# values-dev.yaml
extraEnv:
  - name: API_URL
    value: "https://example-api-dev.tail876052.ts.net"
  - name: AUTH0_CLIENT_ID
    value: "zmw8EuQB4gx69pasbRH73pRaAVygaqck"

# values-prd.yaml
extraEnv:
  - name: API_URL
    value: "https://api.untrustedonline.org"
  - name: AUTH0_CLIENT_ID
    value: "UYwE32zAqDFINkUwvKrATe3b8gtD4hC8"
```

### example-api

```yaml
# values.yaml (base)
env:
  - name: AUTH0_DOMAIN
    value: "dev-tgrsoxiakeqdr1gg.us.auth0.com"
  - name: AUTH0_AUDIENCE
    value: "https://api.untrustedonline.org"
```

## Current Configuration

### Auth0 Tenant

- **Domain**: `dev-tgrsoxiakeqdr1gg.us.auth0.com`
- **API Audience**: `https://api.untrustedonline.org`

### Client IDs

| Environment | Application | Client ID |
|-------------|-------------|-----------|
| DEV | example-ui-dev | `zmw8EuQB4gx69pasbRH73pRaAVygaqck` |
| PRD | example-ui-prd | `UYwE32zAqDFINkUwvKrATe3b8gtD4hC8` |

## Disable Dev Keys Warning

Если не используешь Social Connections (Google, Facebook login):

1. Auth0 Dashboard → Authentication → Social
2. Отключи все провайдеры с пометкой "Dev Keys"

## Troubleshooting

### "Unable to verify token"

- Проверь `AUTH0_DOMAIN` в API (без `https://`)
- Проверь `AUTH0_AUDIENCE` совпадает в UI и API

### CORS errors

- Проверь Allowed Web Origins в Auth0 включает origin UI
- Проверь CORS настроен в Spring Boot API

### Callback URL mismatch

- URL должен точно совпадать (включая trailing slash)
- Проверь протокол (http vs https)

## Next Step

[03-spring-boot-proxy.md](03-spring-boot-proxy.md) - Spring Boot behind reverse proxy
