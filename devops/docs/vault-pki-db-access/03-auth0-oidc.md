# Auth0 OIDC Integration

## 1. Create Auth0 Application

В Auth0 Dashboard:

1. **Applications** → **Create Application**
2. Name: `Vault`
3. Type: **Regular Web Application**
4. Settings:
   - **Allowed Callback URLs**:
     ```
     https://vault.trout-paradise.ts.net/ui/vault/auth/oidc/oidc/callback
     http://localhost:8250/oidc/callback
     ```
   - **Allowed Logout URLs**: `https://vault.trout-paradise.ts.net`
5. Advanced Settings → OAuth:
   - **Signing Algorithm**: RS256
6. Save credentials:
   - Client ID → `infrastructure/apps/values.yaml` (vault.oidcClientId)
   - Client Secret → Doppler (VAULT_OIDC_CLIENT_SECRET)

## 2. Auth0 Roles

**User Management** → **Roles** → Create:

| Name | Описание |
|------|----------|
| `db-admin` | Full PKI access (issue any cert) |
| `db-readonly` | Issue readonly certificates |
| `db-readwrite` | Issue readwrite certificates |

## 3. Auth0 Action

**Actions** → **Library** → **Build Custom** → **Post Login**

Name: `Add Vault Roles`

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://vault/roles';

  if (event.authorization) {
    const roles = event.authorization.roles || [];
    api.idToken.setCustomClaim(namespace, roles);
    api.accessToken.setCustomClaim(namespace, roles);

    // Add email claim (required for Vault user_claim)
    if (event.user.email) {
      api.idToken.setCustomClaim('email', event.user.email);
    }
  }
};
```

**Deploy** и добавить в **Actions** → **Flows** → **Login**.

## 4. Store Credentials

### Doppler (shared)

```
VAULT_OIDC_CLIENT_SECRET=<client_secret>
```

### infrastructure/apps/values.yaml

```yaml
global:
  vault:
    oidcClientId: Y8QpXWQDlKjhTUMaDvnkb5sbsufiHLyP
```

## 5. Vault Configuration (GitOps)

`infrastructure/charts/vault-config/values.yaml`:

```yaml
oidc:
  enabled: true
  discoveryUrl: ""      # Set in ArgoCD values
  clientId: ""          # Set in ArgoCD values
  defaultRole: "default"

  role:
    userClaim: "email"
    groupsClaim: "https://vault/roles"
    tokenTtl: "168h"  # 7 days
    # Request email scope from Auth0 to include email claim
    oidcScopes:
      - "openid"
      - "profile"
      - "email"
    allowedRedirectUris:
      - "http://localhost:8250/oidc/callback"

# UI Configuration - OIDC as default login method
ui:
  defaultAuthMethod: "oidc"

externalGroups:
  - name: "db-admin"
    policies:
      - "pki-admin"
  - name: "db-readonly"
    policies:
      - "pki-readonly"
  - name: "db-readwrite"
    policies:
      - "pki-readwrite"
```

**Важно:** `oidcScopes` включает `email` scope - это нужно для получения email claim от Auth0.

ArgoCD Application добавляет `discoveryUrl`, `clientId` и Tailscale callback URL.

## 6. Test SSO Login

### Web UI

1. Открыть `https://vault.trout-paradise.ts.net`
2. Method: **OIDC**
3. Role: **default**
4. Sign in → Auth0 redirect
5. Проверить policies в Vault UI

### CLI

```bash
export VAULT_ADDR="https://vault.trout-paradise.ts.net"
vault login -method=oidc

# Check token
vault token lookup
```

## 7. Troubleshooting

### "claim 'email' not found in token"

Auth0 Action не добавляет email claim. Обновить Action:

```javascript
api.idToken.setCustomClaim('email', event.user.email);
```

### "no matching role"

Проверить groups claim namespace совпадает:
- Auth0 Action: `https://vault/roles`
- Vault OIDC role: `groups_claim="https://vault/roles"`

### "redirect_uri mismatch"

Добавить URL в Auth0 Application → Allowed Callback URLs.

## Next Steps

→ [04-policies.md](04-policies.md)
