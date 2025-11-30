# Migration: Phase 5 Refactoring

## Current State

Установлено (но нужно удалить):
- MetalLB
- Traefik
- cert-manager
- Tailscale Operator (частично)

## Target State

- Tailscale Operator + Service
- NGINX Ingress Controller
- oauth2-proxy + Auth0
- Redis

## Step-by-Step Migration

### Step 1: Remove Obsolete Components

Удалить из `example-infrastructure`:

```bash
# Apps to delete
rm apps/templates/network/metallb.yaml
rm apps/templates/network/metallb-config.yaml
rm apps/templates/network/traefik.yaml
rm apps/templates/network/cert-manager.yaml
rm apps/templates/network/cert-manager-issuer.yaml

# Manifests to delete
rm -rf manifests/network/metallb-config/
rm -rf manifests/network/cert-manager-issuer/

# Helm values to delete
rm helm-values/network/traefik.yaml
rm helm-values/network/cert-manager.yaml
```

### Step 2: Update Tailscale Setup

Keep existing:
- `apps/templates/network/tailscale-credentials.yaml`
- `apps/templates/network/tailscale-operator.yaml`
- `manifests/network/tailscale-credentials/`

Update Tailscale Ingresses:
```bash
# Remove old ArgoCD ingress (will use NGINX)
rm apps/templates/network/tailscale-ingresses.yaml
rm -rf manifests/network/tailscale-ingresses/
```

### Step 3: Add NGINX Ingress Controller

Create:
```
apps/templates/network/nginx-ingress.yaml          # Wave 12
helm-values/network/nginx-ingress.yaml
manifests/network/tailscale-nginx-service/service.yaml
```

### Step 4: Add Auth0 Credentials

Create:
```
apps/templates/network/auth0-credentials.yaml      # Wave 13
manifests/network/auth0-credentials/external-secret.yaml
```

Doppler secrets needed:
- `AUTH0_DOMAIN`
- `AUTH0_CLIENT_ID_OAUTH2_PROXY`
- `AUTH0_CLIENT_SECRET_OAUTH2_PROXY`
- `OAUTH2_PROXY_COOKIE_SECRET`

### Step 5: Add Redis

Create:
```
apps/templates/network/redis.yaml                  # Wave 14
helm-values/network/redis.yaml
manifests/network/redis-credentials/external-secret.yaml
```

Doppler secrets needed:
- `REDIS_PASSWORD`

### Step 6: Add oauth2-proxy

Create:
```
apps/templates/network/oauth2-proxy.yaml           # Wave 15
helm-values/network/oauth2-proxy.yaml
```

### Step 7: Add ArgoCD OIDC Config

Create:
```
apps/templates/cicd/argocd-oidc-config.yaml        # Wave 16
manifests/cicd/argocd-oidc-config/argocd-cm-patch.yaml
manifests/cicd/argocd-oidc-config/argocd-rbac-cm-patch.yaml
manifests/cicd/argocd-oidc-config/external-secret.yaml
```

Doppler secrets needed:
- `AUTH0_CLIENT_ID_ARGOCD`
- `AUTH0_CLIENT_SECRET_ARGOCD`

### Step 8: Add Protected Ingresses

Create:
```
apps/templates/network/protected-ingresses.yaml    # Wave 17
manifests/network/ingresses/argocd-ingress.yaml
manifests/network/ingresses/longhorn-ingress.yaml
```

## Files Summary

### Delete
```
apps/templates/network/metallb.yaml
apps/templates/network/metallb-config.yaml
apps/templates/network/traefik.yaml
apps/templates/network/cert-manager.yaml
apps/templates/network/cert-manager-issuer.yaml
apps/templates/network/tailscale-ingresses.yaml
manifests/network/metallb-config/
manifests/network/cert-manager-issuer/
manifests/network/tailscale-ingresses/
helm-values/network/traefik.yaml
helm-values/network/cert-manager.yaml
```

### Keep
```
apps/templates/network/tailscale-credentials.yaml
apps/templates/network/tailscale-operator.yaml
manifests/network/tailscale-credentials/
helm-values/network/tailscale-operator.yaml
```

### Create
```
apps/templates/network/nginx-ingress.yaml
apps/templates/network/auth0-credentials.yaml
apps/templates/network/redis.yaml
apps/templates/network/oauth2-proxy.yaml
apps/templates/network/protected-ingresses.yaml
apps/templates/cicd/argocd-oidc-config.yaml
helm-values/network/nginx-ingress.yaml
helm-values/network/redis.yaml
helm-values/network/oauth2-proxy.yaml
manifests/network/tailscale-nginx-service/
manifests/network/auth0-credentials/
manifests/network/redis-credentials/
manifests/network/ingresses/
manifests/cicd/argocd-oidc-config/
```

## Doppler Secrets (All)

| Key | Description |
|-----|-------------|
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth |
| `AUTH0_DOMAIN` | e.g. example-dev.auth0.com |
| `AUTH0_CLIENT_ID_OAUTH2_PROXY` | oauth2-proxy app |
| `AUTH0_CLIENT_SECRET_OAUTH2_PROXY` | oauth2-proxy app |
| `AUTH0_CLIENT_ID_ARGOCD` | ArgoCD app |
| `AUTH0_CLIENT_SECRET_ARGOCD` | ArgoCD app |
| `OAUTH2_PROXY_COOKIE_SECRET` | 32-byte random |
| `REDIS_PASSWORD` | Redis auth |

## Sync Waves (Final)

| Wave | Component |
|------|-----------|
| 3 | Longhorn |
| 4 | External Secrets Operator |
| 5 | ClusterSecretStores |
| 6 | Docker Credentials |
| 7 | ArgoCD Image Updater |
| 8 | Image Updater Config |
| 9 | Tailscale Credentials |
| 10 | Tailscale Operator |
| 11 | Tailscale NGINX Service |
| 12 | NGINX Ingress Controller |
| 13 | Auth0 Credentials |
| 14 | Redis |
| 15 | oauth2-proxy |
| 16 | ArgoCD OIDC Config |
| 17 | Protected Ingresses |

## Verification Checklist

- [ ] Old components deleted from repo
- [ ] Doppler secrets configured
- [ ] Auth0 tenant + applications created
- [ ] Tailscale ACL updated
- [ ] Git push → ArgoCD syncs
- [ ] NGINX Ingress running
- [ ] oauth2-proxy running
- [ ] ArgoCD accessible via Auth0 login
- [ ] Longhorn accessible via Auth0 login
