# Phase 5: Private Networking + Auth

## Overview

Эта фаза настраивает **private access** к internal сервисам через:
- Tailscale VPN (network layer)
- NGINX Ingress Controller (routing + auth)
- oauth2-proxy + Auth0 (authentication)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TAILSCALE VPN                                      │
│                                                                              │
│   Your Device (Tailscale Client)                                            │
│         │                                                                    │
│         ▼                                                                    │
│   ┌─────────────────────────────────────────────────────────────────┐       │
│   │  Tailscale Service (LoadBalancer class: tailscale)              │       │
│   │  internal.tailnet-xxxx.ts.net                                   │       │
│   │                         │                                        │       │
│   │                         ▼                                        │       │
│   │  ┌───────────────────────────────────────────────────────┐      │       │
│   │  │  NGINX Ingress Controller (ClusterIP)                 │      │       │
│   │  │                                                        │      │       │
│   │  │  Ingress annotations:                                  │      │       │
│   │  │    auth-url: http://oauth2-proxy/oauth2/auth          │      │       │
│   │  │    auth-signin: https://auth.internal.ts.net/start    │      │       │
│   │  │                         │                              │      │       │
│   │  │                         ▼                              │      │       │
│   │  │  ┌─────────────────────────────────────────────┐      │      │       │
│   │  │  │  oauth2-proxy                                │      │      │       │
│   │  │  │  - provider: oidc (Auth0)                   │      │      │       │
│   │  │  │  - upstream: static://202                   │      │      │       │
│   │  │  │  - redis session store                      │      │      │       │
│   │  │  └─────────────────────────────────────────────┘      │      │       │
│   │  │                         │                              │      │       │
│   │  │              (authenticated)                           │      │       │
│   │  │                         ▼                              │      │       │
│   │  │  ┌─────────────────────────────────────────────┐      │      │       │
│   │  │  │  Backend Services                            │      │      │       │
│   │  │  │  - argocd.internal.ts.net → ArgoCD          │      │      │       │
│   │  │  │  - longhorn.internal.ts.net → Longhorn      │      │      │       │
│   │  │  │  - grafana.internal.ts.net → Grafana        │      │      │       │
│   │  │  └─────────────────────────────────────────────┘      │      │       │
│   │  └───────────────────────────────────────────────────────┘      │       │
│   └─────────────────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Security Layers

| Layer | Component | What it does |
|-------|-----------|--------------|
| 1. Network | Tailscale VPN | Only tailnet devices can connect |
| 2. Transport | Tailscale TLS | Auto Let's Encrypt certificates |
| 3. Application | oauth2-proxy + Auth0 | OIDC authentication |

## Components

| Component | Version | Wave | Purpose |
|-----------|---------|------|---------|
| Tailscale Credentials | - | 9 | ExternalSecret для OAuth |
| Tailscale Operator | 1.90.9 | 10 | VPN + Service exposure |
| Tailscale Service | - | 11 | Expose NGINX to tailnet |
| NGINX Ingress | 4.12.x | 12 | Internal routing + auth |
| Auth0 Credentials | - | 13 | ExternalSecret для Auth0 |
| Redis | 7.x | 14 | oauth2-proxy sessions |
| oauth2-proxy | 7.x | 15 | Auth middleware |
| ArgoCD OIDC | - | 16 | Auth0 integration |
| Ingresses | - | 17 | Protected services |

## Files Structure

```
example-infrastructure/
├── apps/templates/
│   ├── core/
│   │   └── ... (existing)
│   ├── network/
│   │   ├── tailscale-credentials.yaml    # Wave 9
│   │   ├── tailscale-operator.yaml       # Wave 10
│   │   ├── tailscale-nginx-service.yaml  # Wave 11
│   │   ├── nginx-ingress.yaml            # Wave 12
│   │   ├── auth0-credentials.yaml        # Wave 13
│   │   ├── redis.yaml                    # Wave 14
│   │   ├── oauth2-proxy.yaml             # Wave 15
│   │   └── protected-ingresses.yaml      # Wave 17
│   └── cicd/
│       └── argocd-oidc-config.yaml       # Wave 16
├── helm-values/
│   └── network/
│       ├── nginx-ingress.yaml
│       ├── redis.yaml
│       └── oauth2-proxy.yaml
└── manifests/
    └── network/
        ├── tailscale-credentials/
        ├── auth0-credentials/
        └── ingresses/
```

## Prerequisites

Before starting:

1. **Tailscale Account**
   - OAuth client created
   - ACL configured
   - HTTPS enabled

2. **Auth0 Account**
   - Tenant created
   - Applications configured

3. **Doppler Secrets**
   - `TS_OAUTH_CLIENT_ID`
   - `TS_OAUTH_CLIENT_SECRET`
   - `AUTH0_DOMAIN`
   - `AUTH0_CLIENT_ID`
   - `AUTH0_CLIENT_SECRET`
   - `OAUTH2_PROXY_COOKIE_SECRET`

## Documentation

| Doc | Description |
|-----|-------------|
| [01-tailscale-setup.md](01-tailscale-setup.md) | Tailscale prerequisites + operator |
| [02-nginx-ingress.md](02-nginx-ingress.md) | NGINX Ingress Controller |
| [03-auth0-setup.md](03-auth0-setup.md) | Auth0 configuration |
| [04-oauth2-proxy.md](04-oauth2-proxy.md) | oauth2-proxy deployment |
| [05-protected-ingresses.md](05-protected-ingresses.md) | ArgoCD, Longhorn, Grafana |

## What's Removed

These components are NO LONGER needed:

| Component | Reason |
|-----------|--------|
| MetalLB | Tailscale + Cloudflare don't need LoadBalancer IPs |
| Traefik | Replaced by NGINX (better auth annotations support) |
| cert-manager | TLS from Tailscale (internal) / Cloudflare (public) |
| ClusterIssuers | Not needed without cert-manager |
