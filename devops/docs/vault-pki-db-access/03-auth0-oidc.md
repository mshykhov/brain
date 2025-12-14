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
   - Client ID
   - Client Secret

## 2. Auth0 Action (уже создан)

Action `Add Teleport Traits` уже добавляет роли в токен:

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://teleport';

  if (!event.authorization || !event.authorization.roles) {
    return;
  }

  const roles = event.authorization.roles;

  // Set claims for Vault
  api.idToken.setCustomClaim(`${namespace}/roles`, roles);
};
```

## 3. Store Credentials in Doppler

В Doppler project `shared`:

```
VAULT_OIDC_CLIENT_ID=<client_id>
VAULT_OIDC_CLIENT_SECRET=<client_secret>
```

## 4. Enable OIDC Auth in Vault

```bash
VAULT_POD="vault-0"

# Enable OIDC auth method
kubectl exec -n vault $VAULT_POD -- vault auth enable oidc

# Configure Auth0 as OIDC provider
kubectl exec -n vault $VAULT_POD -- vault write auth/oidc/config \
    oidc_discovery_url="https://login.gaynance.com/" \
    oidc_client_id="<CLIENT_ID>" \
    oidc_client_secret="<CLIENT_SECRET>" \
    default_role="default"
```

## 5. Create OIDC Roles

### Default Role (base access)

```bash
kubectl exec -n vault $VAULT_POD -- vault write auth/oidc/role/default \
    bound_audiences="<CLIENT_ID>" \
    allowed_redirect_uris="https://vault.trout-paradise.ts.net/ui/vault/auth/oidc/oidc/callback" \
    allowed_redirect_uris="http://localhost:8250/oidc/callback" \
    user_claim="email" \
    groups_claim="https://teleport/roles" \
    policies="default" \
    ttl=12h
```

## 6. Create External Groups

Маппинг Auth0 roles → Vault groups:

```bash
# Get OIDC accessor
ACCESSOR=$(kubectl exec -n vault $VAULT_POD -- vault auth list -format=json | jq -r '.["oidc/"].accessor')

# Create external groups for each Auth0 role

# db-admin group
kubectl exec -n vault $VAULT_POD -- vault write identity/group \
    name="db-admin" \
    type="external" \
    policies="pki-admin"

ADMIN_GROUP_ID=$(kubectl exec -n vault $VAULT_POD -- vault read -field=id identity/group/name/db-admin)

kubectl exec -n vault $VAULT_POD -- vault write identity/group-alias \
    name="db-admin" \
    mount_accessor="$ACCESSOR" \
    canonical_id="$ADMIN_GROUP_ID"

# db-readonly group
kubectl exec -n vault $VAULT_POD -- vault write identity/group \
    name="db-readonly" \
    type="external" \
    policies="pki-readonly"

READONLY_GROUP_ID=$(kubectl exec -n vault $VAULT_POD -- vault read -field=id identity/group/name/db-readonly)

kubectl exec -n vault $VAULT_POD -- vault write identity/group-alias \
    name="db-readonly" \
    mount_accessor="$ACCESSOR" \
    canonical_id="$READONLY_GROUP_ID"

# db-readwrite group
kubectl exec -n vault $VAULT_POD -- vault write identity/group \
    name="db-readwrite" \
    type="external" \
    policies="pki-readwrite"

READWRITE_GROUP_ID=$(kubectl exec -n vault $VAULT_POD -- vault read -field=id identity/group/name/db-readwrite)

kubectl exec -n vault $VAULT_POD -- vault write identity/group-alias \
    name="db-readwrite" \
    mount_accessor="$ACCESSOR" \
    canonical_id="$READWRITE_GROUP_ID"

# db-app-blackpoint group
kubectl exec -n vault $VAULT_POD -- vault write identity/group \
    name="db-app-blackpoint" \
    type="external" \
    policies="pki-app-blackpoint"

BLACKPOINT_GROUP_ID=$(kubectl exec -n vault $VAULT_POD -- vault read -field=id identity/group/name/db-app-blackpoint)

kubectl exec -n vault $VAULT_POD -- vault write identity/group-alias \
    name="db-app-blackpoint" \
    mount_accessor="$ACCESSOR" \
    canonical_id="$BLACKPOINT_GROUP_ID"

# db-env-dev group
kubectl exec -n vault $VAULT_POD -- vault write identity/group \
    name="db-env-dev" \
    type="external" \
    policies="pki-env-dev"

DEV_GROUP_ID=$(kubectl exec -n vault $VAULT_POD -- vault read -field=id identity/group/name/db-env-dev)

kubectl exec -n vault $VAULT_POD -- vault write identity/group-alias \
    name="db-env-dev" \
    mount_accessor="$ACCESSOR" \
    canonical_id="$DEV_GROUP_ID"

# db-env-prd group
kubectl exec -n vault $VAULT_POD -- vault write identity/group \
    name="db-env-prd" \
    type="external" \
    policies="pki-env-prd"

PRD_GROUP_ID=$(kubectl exec -n vault $VAULT_POD -- vault read -field=id identity/group/name/db-env-prd)

kubectl exec -n vault $VAULT_POD -- vault write identity/group-alias \
    name="db-env-prd" \
    mount_accessor="$ACCESSOR" \
    canonical_id="$PRD_GROUP_ID"
```

## 7. Test OIDC Login

```bash
# CLI login (opens browser)
vault login -method=oidc

# Check token info
vault token lookup

# Should show policies from your Auth0 roles
```

## Next Steps

→ [04-policies.md](04-policies.md)
