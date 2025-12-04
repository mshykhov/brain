# Auth0 Refresh Tokens

## Problem

Error: `Missing Refresh Token (audience: '...', scope: 'openid profile email offline_access')`

## Solution

Для получения refresh tokens нужно:

1. **Auth0 Dashboard**: Enable "Allow Offline Access" в API settings
2. **Frontend**: Добавить `offline_access` scope

## Auth0 Dashboard

1. Applications → APIs → Your API
2. Settings → Access Settings
3. Enable "Allow Offline Access"

## Frontend Configuration

```typescript
// modules/ui/src/main.tsx
<Auth0Provider
  domain={AUTH0_CONFIG.domain}
  clientId={AUTH0_CONFIG.clientId}
  authorizationParams={{
    redirect_uri: window.location.origin,
    audience: AUTH0_CONFIG.audience || undefined,
    scope: "openid profile email offline_access",  // Add offline_access!
  }}
  useRefreshTokens={true}
  cacheLocation="localstorage"
>
```

## Key Settings

| Setting | Value | Description |
|---------|-------|-------------|
| scope | `offline_access` | OAuth 2.0 standard для refresh tokens |
| useRefreshTokens | `true` | Auth0 SDK использует refresh tokens |
| cacheLocation | `localstorage` | Persist tokens между сессиями |

## Official Docs

- [Auth0 Refresh Tokens](https://auth0.com/docs/secure/tokens/refresh-tokens)
- [OAuth 2.0 offline_access](https://oauth.net/2/scope/)
