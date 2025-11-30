# Migration: Phase 5 - Private Access with Auth0

## Architecture

```
Tailscale LB (per service) → NGINX Ingress → oauth2-proxy → Backend
        ↓                         ↓               ↓
  longhorn.ts.net            Host routing    Auth0 OIDC
  argocd.ts.net              + auth-url      Authentication
```

## Current State (After Migration)

- Tailscale Operator + LoadBalancer per service (separate hostnames)
- NGINX Ingress Controller (routing with auth annotations)
- oauth2-proxy + Auth0 (centralized OIDC authentication)
- No Redis (cookie-based sessions)

## Manual Changes Required

**IMPORTANT:** Only one file to change:

### 1. Tailnet Name

Find your tailnet name:
- Tailscale Admin Console → Settings → General → Tailnet name
- Or: `kubectl get svc -n ingress-nginx`

Update in: `charts/protected-services/values.yaml`
```yaml
tailnet: tail876052  # Change this
```

### 2. Auth0 Callback URLs

Add to Auth0 Application → Settings:

**Allowed Callback URLs:**
```
https://longhorn.<tailnet>.ts.net/oauth2/callback
https://argocd.<tailnet>.ts.net/oauth2/callback
```

**Allowed Logout URLs:**
```
https://longhorn.<tailnet>.ts.net
https://argocd.<tailnet>.ts.net
```

**Allowed Web Origins:**
```
https://longhorn.<tailnet>.ts.net
https://argocd.<tailnet>.ts.net
```

### 3. Enable/Disable Services

Edit `charts/protected-services/values.yaml`:
```yaml
services:
  longhorn:
    enabled: true   # or false
  argocd:
    enabled: true   # or false
```

## Sync Waves

| Wave | Component |
|------|-----------|
| 9 | Tailscale Credentials |
| 10 | Tailscale Operator |
| 12 | NGINX Ingress Controller |
| 14 | Auth0 Credentials |
| 15 | oauth2-proxy |
| 17 | Protected Services (Helm chart) |

## Files

```
apps/templates/network/
├── nginx-ingress.yaml           # Wave 12
├── auth0-credentials.yaml       # Wave 14
├── oauth2-proxy.yaml            # Wave 15
└── protected-services.yaml      # Wave 17

charts/protected-services/
├── Chart.yaml
├── values.yaml                  # <-- CHANGE TAILNET HERE
└── templates/
    ├── tailscale-services.yaml  # Creates LB per service
    ├── ingresses.yaml           # Protected ingresses
    └── oauth2-proxy-ingress.yaml

helm-values/network/
├── nginx-ingress.yaml
└── oauth2-proxy.yaml

manifests/network/
└── auth0-credentials/
    ├── namespace.yaml
    └── external-secret.yaml
```

## Doppler Secrets (shared config)

| Key | Where to get |
|-----|--------------|
| `AUTH0_DOMAIN` | Auth0 Dashboard → Settings → Domain |
| `AUTH0_CLIENT_ID_OAUTH2_PROXY` | Auth0 → Applications → oauth2-proxy → Client ID |
| `AUTH0_CLIENT_SECRET_OAUTH2_PROXY` | Auth0 → Applications → oauth2-proxy → Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | Generate: `head -c 32 /dev/urandom \| base64 \| head -c 32` |

## Auth0 Setup

See: [docs/phase5/03-auth0-setup.md](docs/phase5/03-auth0-setup.md)

## Pre-Deploy Checklist

- [ ] Auth0 tenant created
- [ ] Auth0 Application created (Regular Web App)
- [ ] Callback URLs configured in Auth0 (without `internal.`!)
- [ ] Doppler secrets added to `shared` config
- [ ] `charts/protected-services/values.yaml` - tailnet updated
- [ ] Git push → ArgoCD syncs

## Post-Deploy Verification

- [ ] NGINX Ingress Controller running
- [ ] oauth2-proxy running
- [ ] Tailscale services created: `kubectl get svc -n ingress-nginx`
- [ ] Access `https://longhorn.<tailnet>.ts.net` → Auth0 login
- [ ] Access `https://argocd.<tailnet>.ts.net` → Auth0 login
