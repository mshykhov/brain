# Auth0 OIDC Integration for Vault

## 1. Create Auth0 Application

В Auth0 Dashboard:

1. **Applications** → **Create Application**
2. Name: `Vault`
3. Type: **Regular Web Application**
4. Settings:
   - **Allowed Callback URLs**: `https://vault.trout-paradise.ts.net/ui/vault/auth/oidc/oidc/callback`
   - **Allowed Logout URLs**: `https://vault.trout-paradise.ts.net`
5. Save и скопируй:
   - Client ID → `infrastructure/apps/values.yaml`
   - Client Secret → Doppler

## 2. Auth0 Roles

**User Management** → **Roles** → Create:

| Name | Vault Policy | Описание |
|------|--------------|----------|
| `db-admin` | pki-admin | Full PKI access |
| `db-readonly` | pki-readonly | Issue readonly certs |
| `db-readwrite` | pki-readwrite | Issue readwrite certs |

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
vault:
  oidcClientId: Y8QpXWQDlKjhTUMaDvnkb5sbsufiHLyP
```

## 5. Vault Configuration

vault-config chart автоматически создаёт:

### External Groups

```yaml
externalGroups:
  - name: db-admin
    policies: [pki-admin]
  - name: db-readonly
    policies: [pki-readonly]
  - name: db-readwrite
    policies: [pki-readwrite]
```

Auth0 role → Vault external group → Vault policy

### OIDC Role

```yaml
oidc:
  role:
    groupsClaim: "https://vault/roles"
```

## 6. Test SSO Login

1. Открыть `https://vault.trout-paradise.ts.net`
2. Method: **OIDC**
3. Role: **default**
4. Sign in → Auth0 redirect
5. Проверить policies в Vault UI

## Next Steps

→ [03-cnpg-certificates.md](03-cnpg-certificates.md)
