# Auth0 OIDC Integration

## 1. Create Auth0 Application

В Auth0 Dashboard:

1. **Applications** → **Create Application**
2. Name: `Teleport`
3. Type: **Regular Web Application**
4. Settings:
   - **Allowed Callback URLs**: `https://teleport.trout-paradise.ts.net/v1/webapi/oidc/callback`
   - **Allowed Logout URLs**: `https://teleport.trout-paradise.ts.net`
5. Save и скопируй:
   - Client ID
   - Client Secret
   - Domain

## 2. Configure Auth0 Groups

### Enable Authorization Extension (если нужны группы)

1. **Extensions** → Install **Authorization**
2. Создай группы:
   - `db-readonly` - только чтение
   - `db-admin` - полный доступ
3. Назначь пользователей в группы

### Или используй Auth0 Organizations/Roles

В **User Management** → **Roles**:
- `db-readonly`
- `db-admin`

## 3. Add Groups to Token

В **Auth Pipeline** → **Rules** или **Actions**:

```javascript
// Action: Add groups to token
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://teleport/';

  if (event.authorization) {
    api.idToken.setCustomClaim(namespace + 'groups', event.authorization.roles);
    api.accessToken.setCustomClaim(namespace + 'groups', event.authorization.roles);
  }
};
```

## 4. Store Credentials in Doppler

В Doppler project `shared`:

```
TELEPORT_OIDC_CLIENT_ID=<client_id>
TELEPORT_OIDC_CLIENT_SECRET=<client_secret>
```

## 5. Create ExternalSecret

`infrastructure/charts/teleport-cluster/templates/external-secret.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: teleport-oidc
  namespace: teleport
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: teleport-oidc
    creationPolicy: Owner
  data:
    - secretKey: client_id
      remoteRef:
        key: TELEPORT_OIDC_CLIENT_ID
    - secretKey: client_secret
      remoteRef:
        key: TELEPORT_OIDC_CLIENT_SECRET
```

## 6. Create OIDC Connector

```yaml
# oidc-connector.yaml
kind: oidc
version: v3
metadata:
  name: auth0
spec:
  issuer_url: https://login.gaynance.com/
  client_id: <from_secret>
  client_secret: <from_secret>
  redirect_url: https://teleport.trout-paradise.ts.net/v1/webapi/oidc/callback

  # Map Auth0 groups to Teleport roles
  claims_to_roles:
    - claim: "https://teleport/groups"
      value: "db-admin"
      roles:
        - db-admin
        - access
    - claim: "https://teleport/groups"
      value: "db-readonly"
      roles:
        - db-readonly
        - access

  # Default role for all authenticated users
  claims_to_roles:
    - claim: "email_verified"
      value: "true"
      roles:
        - access
```

## 7. Apply Connector

```bash
AUTH_POD=$(kubectl get pod -n teleport -l app=teleport-cluster -o jsonpath='{.items[0].metadata.name}')

# Create connector
kubectl exec -n teleport -it $AUTH_POD -- tctl create -f - <<EOF
kind: oidc
version: v3
metadata:
  name: auth0
spec:
  issuer_url: https://login.gaynance.com/
  client_id: YOUR_CLIENT_ID
  client_secret: YOUR_CLIENT_SECRET
  redirect_url: https://teleport.trout-paradise.ts.net/v1/webapi/oidc/callback
  claims_to_roles:
    - claim: "https://teleport/groups"
      value: "db-admin"
      roles:
        - db-admin
        - access
    - claim: "https://teleport/groups"
      value: "db-readonly"
      roles:
        - db-readonly
        - access
EOF
```

## 8. Test SSO Login

```bash
# Login via SSO
tsh login --proxy=teleport.trout-paradise.ts.net

# Should open browser with Auth0 login
# After login, check status
tsh status
```

## Next Steps

→ [03-database-agent.md](03-database-agent.md)
