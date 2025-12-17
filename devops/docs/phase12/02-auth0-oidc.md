# Auth0 OIDC Integration

## 1. Create Auth0 Application

1. **Applications** → **Create Application**
2. Name: `Vault`
3. Type: **Regular Web Application**
4. Settings:
   - Callback URL: `https://vault.{tailnet}.ts.net/ui/vault/auth/oidc/oidc/callback`
   - Logout URL: `https://vault.{tailnet}.ts.net`
5. Save и скопируй Client ID / Client Secret

## 2. Auth0 Roles

**User Management** → **Roles** → Create:

| Role | Format | Example |
|------|--------|---------|
| DB access | db:{app}:{env}:{access} | db:blackpoint:dev:readonly |

Примеры:
- `db:blackpoint:dev:readonly` - чтение dev БД blackpoint
- `db:blackpoint:prd:admin` - админ prod БД blackpoint
- `db:notifier:dev:readwrite` - запись dev БД notifier

## 3. Auth0 Action (Post Login)

**Actions** → **Library** → **Build Custom**

Name: `Add Vault Roles`

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://vault/roles';
  if (event.authorization) {
    const roles = event.authorization.roles || [];
    api.idToken.setCustomClaim(namespace, roles);
    api.accessToken.setCustomClaim(namespace, roles);
  }
};
```

Deploy и добавить в **Login Flow**.

## 4. Store Credentials

### Doppler (shared)

```
VAULT_OIDC_CLIENT_SECRET=<client_secret>
```

### infrastructure/apps/values.yaml

```yaml
vault:
  oidcClientId: <client_id>
  oidcDiscoveryUrl: https://your-tenant.auth0.com/
```

## 5. Vault Configuration

vault-config chart автоматически создаёт:

- OIDC auth method
- Default role с groups claim `https://vault/roles`
- External groups mapping Auth0 roles → Vault policies

## 6. Test SSO

1. Открыть `https://vault.{tailnet}.ts.net`
2. Method: **OIDC**
3. Sign in → Auth0 redirect
4. Проверить assigned policies в правом верхнем углу
