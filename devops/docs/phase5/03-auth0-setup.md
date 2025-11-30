# Auth0 Setup

Docs: https://auth0.com/docs/

## Overview

Auth0 обеспечивает централизованную OIDC аутентификацию для всех сервисов.

## Free Tier Limits

| Resource | Limit |
|----------|-------|
| Monthly Active Users | 7,000 |
| Social Connections | Unlimited |
| Applications | Unlimited |

## Step 1: Create Auth0 Account

1. Go to https://auth0.com/signup
2. Create account (можно через GitHub/Google)
3. Create tenant (e.g., `example-dev`)

## Step 2: Create Applications

### Application 1: oauth2-proxy (для всех internal сервисов)

1. Applications → Create Application
2. Name: `oauth2-proxy`
3. Type: **Regular Web Application**
4. Settings:

| Setting | Value |
|---------|-------|
| Allowed Callback URLs | `https://internal.tailnet-xxxx.ts.net/oauth2/callback` |
| Allowed Logout URLs | `https://internal.tailnet-xxxx.ts.net` |
| Allowed Web Origins | `https://internal.tailnet-xxxx.ts.net` |

5. Save Client ID and Client Secret

### Application 2: ArgoCD (native OIDC)

1. Applications → Create Application
2. Name: `argocd`
3. Type: **Regular Web Application**
4. Settings:

| Setting | Value |
|---------|-------|
| Allowed Callback URLs | `https://argocd.internal.tailnet-xxxx.ts.net/auth/callback` |
| Allowed Logout URLs | `https://argocd.internal.tailnet-xxxx.ts.net` |

### Application 3: Grafana (native OIDC)

1. Applications → Create Application
2. Name: `grafana`
3. Type: **Regular Web Application**
4. Settings:

| Setting | Value |
|---------|-------|
| Allowed Callback URLs | `https://grafana.internal.tailnet-xxxx.ts.net/login/generic_oauth` |
| Allowed Logout URLs | `https://grafana.internal.tailnet-xxxx.ts.net` |

## Step 3: Create API (для public example-api)

1. Applications → APIs → Create API
2. Name: `example-api`
3. Identifier: `https://api.example.com`
4. Signing Algorithm: RS256

Этот API используется для JWT validation в Spring Boot.

## Step 4: Configure Groups (RBAC)

Auth0 использует **Actions** для добавления groups в токен.

### Create Action

1. Actions → Flows → Login
2. Add Action → Build Custom
3. Name: `Add Groups to Token`

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://example.com';

  // Get user's roles from Auth0
  const assignedRoles = event.authorization?.roles || [];

  // Add to ID token (for OIDC apps)
  api.idToken.setCustomClaim(`${namespace}/groups`, assignedRoles);

  // Add to access token (for API)
  api.accessToken.setCustomClaim(`${namespace}/groups`, assignedRoles);
};
```

4. Deploy Action
5. Drag to Login Flow

### Create Roles

1. User Management → Roles → Create Role
2. Create roles:
   - `admin` - Full access
   - `developer` - Read access
   - `viewer` - View only

### Assign Roles to Users

1. User Management → Users → Select user
2. Roles → Assign Roles

## Step 5: Add Secrets to Doppler

Add to Doppler → `example` project → `shared` config:

| Key | Value | Description |
|-----|-------|-------------|
| `AUTH0_DOMAIN` | `example-dev.auth0.com` | Your tenant domain |
| `AUTH0_CLIENT_ID_OAUTH2_PROXY` | `xxx` | oauth2-proxy client ID |
| `AUTH0_CLIENT_SECRET_OAUTH2_PROXY` | `xxx` | oauth2-proxy client secret |
| `AUTH0_CLIENT_ID_ARGOCD` | `xxx` | ArgoCD client ID |
| `AUTH0_CLIENT_SECRET_ARGOCD` | `xxx` | ArgoCD client secret |
| `AUTH0_CLIENT_ID_GRAFANA` | `xxx` | Grafana client ID |
| `AUTH0_CLIENT_SECRET_GRAFANA` | `xxx` | Grafana client secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | `xxx` | 32-byte random string |

Generate cookie secret:
```bash
openssl rand -base64 32 | head -c 32
```

## ExternalSecret

```yaml
# manifests/network/auth0-credentials/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: auth0-credentials
  namespace: oauth2-proxy
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: doppler-shared
    kind: ClusterSecretStore
  target:
    name: auth0-credentials
    creationPolicy: Owner
  data:
    - secretKey: client-id
      remoteRef:
        key: AUTH0_CLIENT_ID_OAUTH2_PROXY
    - secretKey: client-secret
      remoteRef:
        key: AUTH0_CLIENT_SECRET_OAUTH2_PROXY
    - secretKey: cookie-secret
      remoteRef:
        key: OAUTH2_PROXY_COOKIE_SECRET
```

## Auth0 OIDC Endpoints

| Endpoint | URL |
|----------|-----|
| Issuer | `https://YOUR_TENANT.auth0.com/` |
| Authorization | `https://YOUR_TENANT.auth0.com/authorize` |
| Token | `https://YOUR_TENANT.auth0.com/oauth/token` |
| UserInfo | `https://YOUR_TENANT.auth0.com/userinfo` |
| JWKS | `https://YOUR_TENANT.auth0.com/.well-known/jwks.json` |

## Verification

```bash
# Test OIDC discovery
curl https://YOUR_TENANT.auth0.com/.well-known/openid-configuration | jq .
```

Sources:
- https://auth0.com/docs/get-started/auth0-overview/create-applications
- https://auth0.com/docs/customize/actions/flows-and-triggers/login-flow
- https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/auth0/
