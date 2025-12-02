# Phase 5 Quick Reference

## Архитектура

```
User → Tailscale VPN → Tailscale Ingress (per service) → NGINX → oauth2-proxy → Backend
```

**3 уровня безопасности:**
1. Network: Tailscale VPN
2. Transport: TLS от Tailscale
3. Application: Auth0 OIDC через oauth2-proxy

## Что изменить

### 1. apps/values.yaml

```yaml
global:
  tailnet: tail876052              # Твой tailnet
  tailscale:
    clientId: kZUmGQedYj11CNTRL    # Tailscale OAuth Client ID
  auth0:
    domain: dev-xxx.us.auth0.com   # Auth0 Domain (без https://)
    clientId: wsZ3vIm5FlxztPisdo3Jq5BaeJvASZrz  # Auth0 Client ID
  dockerhub:
    username: shykhovmyron         # DockerHub username
```

### 2. Doppler (shared config)

| Key | Источник |
|-----|----------|
| `DOCKERHUB_PULL_TOKEN` | DockerHub Access Token |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth Client Secret |
| `AUTH0_CLIENT_SECRET` | Auth0 Application Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | `openssl rand -base64 32 \| head -c 32` |
| `OAUTH2_PROXY_REDIS_PASSWORD` | `openssl rand -base64 32` |

### 3. Auth0 Application Settings

**Allowed Callback URLs:**
```
https://argocd.<tailnet>.ts.net/oauth2/callback,
https://longhorn.<tailnet>.ts.net/oauth2/callback
```

**Allowed Logout URLs:**
```
https://argocd.<tailnet>.ts.net,
https://longhorn.<tailnet>.ts.net
```

### 4. Auth0 Action (REQUIRED)

Actions → Library → Build Custom → "Add Groups to Token":

```javascript
exports.onExecutePostLogin = async (event, api) => {
  const namespace = 'https://ns';
  if (event.authorization && event.authorization.roles) {
    api.idToken.setCustomClaim(`${namespace}/groups`, event.authorization.roles);
    api.accessToken.setCustomClaim(`${namespace}/groups`, event.authorization.roles);
  }
};
```

**Deploy** → Actions → Flows → Login → Add to flow → **Apply**

### 5. Auth0 Roles

User Management → Roles → Create:
- `infra-admins`
- `argocd-admins`
- `longhorn-admins`

Assign to users.

## File Structure

```
example-infrastructure/
├── apps/
│   ├── values.yaml                           # Global values
│   └── templates/
│       ├── cicd/
│       │   └── argocd-config.yaml           # Wave 2
│       ├── core/
│       │   ├── credentials.yaml             # Wave 5
│       │   └── secret-stores.yaml           # Wave 5
│       └── network/
│           ├── tailscale-operator.yaml      # Wave 10
│           ├── nginx-ingress.yaml           # Wave 12
│           ├── oauth2-proxy.yaml            # Wave 15
│           └── protected-services.yaml      # Wave 17
├── charts/
│   ├── argocd-config/                       # Anonymous access
│   ├── credentials/                         # ExternalSecrets
│   └── protected-services/                  # Dynamic ingresses
└── helm-values/
    └── network/
        ├── nginx-ingress.yaml
        ├── oauth2-proxy.yaml
        └── tailscale-operator.yaml
```

## Sync Waves

| Wave | Component |
|------|-----------|
| 2 | ArgoCD Config (anonymous) |
| 5 | Credentials + ClusterSecretStores |
| 10 | Tailscale Operator |
| 12 | NGINX Ingress Controller |
| 15 | oauth2-proxy + Redis |
| 17 | Protected Services |

## Checklist

### Prerequisites
- [ ] Tailscale ACL configured (tagOwners, grants)
- [ ] Tailscale OAuth client (Devices Core, Auth Keys, Services Write)
- [ ] Auth0 tenant + Application created
- [ ] Auth0 Action deployed + in Login flow
- [ ] Auth0 Roles created + assigned

### Doppler Secrets
- [ ] `TS_OAUTH_CLIENT_SECRET`
- [ ] `AUTH0_CLIENT_SECRET`
- [ ] `OAUTH2_PROXY_COOKIE_SECRET`
- [ ] `OAUTH2_PROXY_REDIS_PASSWORD`

### Git
- [ ] `apps/values.yaml` updated
- [ ] Pushed to master

### Verification
- [ ] `kubectl get pods -n tailscale` — operator running
- [ ] `kubectl get pods -n oauth2-proxy` — proxy + redis running
- [ ] `kubectl get pods -n ingress-nginx` — nginx running
- [ ] Tailscale Admin Console — proxies visible
- [ ] https://argocd.&lt;tailnet&gt;.ts.net → Auth0 login → ArgoCD UI

## Troubleshooting

### Groups не работают
1. Auth0 Action deployed?
2. Action в Login flow?
3. User имеет roles?
4. `oidc_groups_claim = "https://ns/groups"` в config?

### 502 Bad Gateway
1. oauth2-proxy running?
2. Redis running?
3. Backend service exists?

### Redirect loop
1. Clear browser cookies
2. Check `cookie_domains` matches host

### ArgoCD показывает login
1. `users.anonymous.enabled: "true"` в argocd-cm?
2. Restart argocd-server

## Docs

- [00-prerequisites.md](docs/phase5/00-prerequisites.md) — Tailscale ACL, OAuth
- [01-tailscale-setup.md](docs/phase5/01-tailscale-setup.md) — Tailscale Operator
- [02-nginx-oauth2-proxy.md](docs/phase5/02-nginx-oauth2-proxy.md) — NGINX + oauth2-proxy
- [03-auth0-setup.md](docs/phase5/03-auth0-setup.md) — Auth0 + Action
- [04-argocd-anonymous.md](docs/phase5/04-argocd-anonymous.md) — Anonymous ArgoCD
- [05-credentials-chart.md](docs/phase5/05-credentials-chart.md) — Credentials chart
- [06-protected-services.md](docs/phase5/06-protected-services.md) — Protected services
- [07-troubleshooting.md](docs/phase5/07-troubleshooting.md) — Troubleshooting
