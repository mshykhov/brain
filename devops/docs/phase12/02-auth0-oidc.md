# Auth0 OIDC Integration

## 1. Create Auth0 Application

В Auth0 Dashboard:

1. **Applications** → **Create Application**
2. Name: `Teleport`
3. Type: **Regular Web Application**
4. Settings:
   - **Allowed Callback URLs**: `https://teleport.trout-paradise.ts.net/v1/webapi/oidc/callback`
   - **Allowed Logout URLs**: `https://teleport.trout-paradise.ts.net`
   - **Allowed Web Origins**: не требуется (server-side OIDC flow)
5. Save и скопируй:
   - Client ID
   - Client Secret
   - Domain

## 2. RBAC Structure (Traits-based)

Используем compositional подход с traits для масштабируемости.

### Auth0 Roles

Создать в **User Management** → **Roles**:

#### Permission roles (выбирается один):
| Name | Description |
|------|-------------|
| `db-readonly` | Database read-only access |
| `db-readwrite` | Database read-write access |

#### App roles (выбираются несколько):
| Name | Description |
|------|-------------|
| `db-app-blackpoint` | Access to Blackpoint databases |
| `db-app-notifier` | Access to Notifier databases |

#### Environment roles (выбираются несколько):
| Name | Description |
|------|-------------|
| `db-env-dev` | Access to dev environment |
| `db-env-prd` | Access to prd environment |

#### Admin (override):
| Name | Description |
|------|-------------|
| `db-admin` | Full database admin access |

### Примеры назначений

| Пользователь | Роли | Доступ |
|--------------|------|--------|
| Junior Dev | `db-readonly` + `db-app-blackpoint` + `db-env-dev` | Читает blackpoint-dev |
| Backend Dev | `db-readwrite` + `db-app-blackpoint` + `db-app-notifier` + `db-env-dev` | Пишет в blackpoint-dev, notifier-dev |
| Senior Dev | `db-readonly` + `db-app-blackpoint` + `db-env-dev` + `db-env-prd` | Читает blackpoint в dev и prd |
| DBA/Admin | `db-admin` | Полный доступ везде |

### Масштабирование

- Новое приложение = 1 новая роль (`db-app-newservice`)
- 10 приложений = 15 ролей (вместо 41 при flat подходе)

## 3. Auth0 Action for Traits

Создаём Action для передачи ролей как traits в токен.

**Actions** → **Library** → **Build Custom** → **Post Login**

Name: `Add Teleport Traits`

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://teleport';

  if (!event.authorization || !event.authorization.roles) {
    return;
  }

  const roles = event.authorization.roles;

  // Parse roles using filter/map
  const apps = roles
    .filter(r => r.startsWith('db-app-'))
    .map(r => r.replace('db-app-', ''));

  const envs = roles
    .filter(r => r.startsWith('db-env-'))
    .map(r => r.replace('db-env-', ''));

  const permission = roles.includes('db-readwrite') ? 'readwrite' : 'readonly';
  const isAdmin = roles.includes('db-admin');

  // Set claims
  api.idToken.setCustomClaim(`${namespace}/apps`, apps);
  api.idToken.setCustomClaim(`${namespace}/envs`, envs);
  api.idToken.setCustomClaim(`${namespace}/permission`, permission);
  api.idToken.setCustomClaim(`${namespace}/is_admin`, isAdmin);
  api.idToken.setCustomClaim(`${namespace}/roles`, roles);
};
```

**Deploy** action и добавить в **Actions** → **Flows** → **Login**.

## 4. Store Credentials in Doppler

В Doppler project `shared`:

```
TELEPORT_OIDC_CLIENT_SECRET=<client_secret>
```

Client ID публичный, хардкодится в ExternalSecret template.

## 5. Create ExternalSecret

`infrastructure/charts/credentials/templates/teleport-oidc.yaml`:

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
    template:
      data:
        client-id: "EiFjtNTcuZzCjpRABGSbea2TAuinVbyp"
        client-secret: "{{ .clientSecret }}"
  data:
    - secretKey: clientSecret
      remoteRef:
        key: TELEPORT_OIDC_CLIENT_SECRET
```

## 6. Create OIDC Connector

```bash
AUTH_POD=$(kubectl get pod -n teleport -l app=teleport-cluster -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n teleport -it $AUTH_POD -- tctl create -f - <<'EOF'
kind: oidc
version: v3
metadata:
  name: auth0
spec:
  issuer_url: https://login.gaynance.com/
  client_id: <CLIENT_ID>
  client_secret: <CLIENT_SECRET>
  redirect_url: https://teleport.trout-paradise.ts.net/v1/webapi/oidc/callback

  # Map claims to traits
  claims_to_roles:
    # Admin gets full access
    - claim: "https://teleport/is_admin"
      value: "true"
      roles:
        - db-admin
        - access

    # All authenticated users get base access
    - claim: "email_verified"
      value: "true"
      roles:
        - db-user
        - access
EOF
```

## 7. Test SSO Login

```bash
# Login via SSO
tsh login --proxy=teleport.trout-paradise.ts.net

# Browser opens → Auth0 login → callback

# Check status and roles
tsh status
```

## Next Steps

→ [03-database-agent.md](03-database-agent.md)
