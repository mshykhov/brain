# Tailscale Kubernetes Operator Setup

## 1. ACL Policy Configuration

В Tailscale Admin Console (https://login.tailscale.com/admin/acls) добавить теги:

```json
{
  "tagOwners": {
    "tag:k8s-operator": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

## 2. OAuth Client

1. Перейти в **Settings → Trust credentials** (https://login.tailscale.com/admin/settings/trust-credentials)
2. Создать OAuth Client:
   - Scopes: `Devices Core`, `Auth Keys`, `Services` (Write)
   - Tag: `tag:k8s-operator`
3. Сохранить Client ID и Client Secret

## 3. Doppler Secrets

Добавить в Doppler (проект `example`, config `shared`):

```
TS_OAUTH_CLIENT_ID=<client-id>
TS_OAUTH_CLIENT_SECRET=<client-secret>
```

## 4. Kubernetes Secret

ClusterExternalSecret создаст Secret `tailscale-operator-oauth` в namespace `tailscale`.
