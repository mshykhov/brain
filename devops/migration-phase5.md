# Migration: Phase 5 - Private Access with Auth0

## Architecture

```
Tailscale VPN → NGINX Ingress → oauth2-proxy → Services
     ↓              ↓               ↓
  Network       Routing          Auth0 OIDC
  Security      + Auth           Authentication
```

## Current State (After Migration)

- Tailscale Operator + Service (exposes NGINX to tailnet)
- NGINX Ingress Controller (routing with auth annotations)
- oauth2-proxy + Auth0 (centralized OIDC authentication)
- No Redis (cookie-based sessions)

## Manual Changes Required

**IMPORTANT:** These files contain example values that must be changed:

### 1. Tailnet Hostname

Find your tailnet name:
- Tailscale Admin Console → Settings → General → Tailnet name
- Or: `kubectl get svc -n tailscale`

Update in these files (replace `tail876052` with your tailnet):

| File | What to change |
|------|----------------|
| `manifests/network/ingresses/longhorn-ingress.yaml` | `host: longhorn.<tailnet>.ts.net` |
| `manifests/network/ingresses/oauth2-proxy-ingress.yaml` | All hosts |
| `manifests/network/ingresses/argocd-ingress.yaml.disabled` | `host: argocd.<tailnet>.ts.net` |

### 2. Auth0 Callback URLs

Add to Auth0 Application → Allowed Callback URLs:
```
https://longhorn.<tailnet>.ts.net/oauth2/callback
https://argocd.<tailnet>.ts.net/oauth2/callback
```

### 3. Enable ArgoCD (after testing Longhorn)

1. Rename: `argocd-ingress.yaml.disabled` → `argocd-ingress.yaml`
2. Uncomment argocd host in `oauth2-proxy-ingress.yaml`
3. Add ArgoCD callback URL to Auth0

## Sync Waves

| Wave | Component |
|------|-----------|
| 9 | Tailscale Credentials |
| 10 | Tailscale Operator |
| 12 | NGINX Ingress Controller |
| 13 | Tailscale NGINX Service |
| 14 | Auth0 Credentials |
| 15 | oauth2-proxy |
| 17 | Protected Ingresses |

## Files Created

```
apps/templates/network/
├── nginx-ingress.yaml           # Wave 12
├── tailscale-nginx-service.yaml # Wave 13
├── auth0-credentials.yaml       # Wave 14
├── oauth2-proxy.yaml            # Wave 15
└── protected-ingresses.yaml     # Wave 17

helm-values/network/
├── nginx-ingress.yaml
└── oauth2-proxy.yaml

manifests/network/
├── tailscale-nginx-service/service.yaml
├── auth0-credentials/
│   ├── namespace.yaml
│   └── external-secret.yaml
└── ingresses/
    ├── longhorn-ingress.yaml
    ├── oauth2-proxy-ingress.yaml
    └── argocd-ingress.yaml.disabled  # Enable after testing
```

## Doppler Secrets

| Key | Where to get |
|-----|--------------|
| `AUTH0_DOMAIN` | Auth0 Dashboard → Settings → Domain |
| `AUTH0_CLIENT_ID_OAUTH2_PROXY` | Auth0 → Applications → oauth2-proxy → Client ID |
| `AUTH0_CLIENT_SECRET_OAUTH2_PROXY` | Auth0 → Applications → oauth2-proxy → Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | Generate: `openssl rand -base64 32 \| head -c 32` |

## Auth0 Setup

See: [docs/phase5/03-auth0-setup.md](docs/phase5/03-auth0-setup.md)

## Pre-Deploy Checklist

- [ ] Auth0 tenant created
- [ ] Auth0 Application created (Regular Web App)
- [ ] Callback URLs configured in Auth0
- [ ] Doppler secrets added
- [ ] **Ingress hosts updated with real tailnet name**
- [ ] Git push → ArgoCD syncs

## Post-Deploy Verification

- [ ] NGINX Ingress Controller running
- [ ] oauth2-proxy running
- [ ] Access `https://longhorn.<tailnet>.ts.net` → Auth0 login
- [ ] (Later) Enable and test ArgoCD
