# Phase 7: Application Configuration

## Overview

Конфигурация приложений (example-api, example-ui) для работы в Kubernetes с Auth0, Tailscale и Cloudflare.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              PRODUCTION                                      │
│                                                                              │
│  Internet → Cloudflare Tunnel → example-api-prd:8080                        │
│                               → example-ui-prd:8080                          │
│                                                                              │
│  Auth: Auth0 (SPA flow для UI, JWT validation для API)                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              DEVELOPMENT                                     │
│                                                                              │
│  Tailscale VPN → Tailscale Ingress → NGINX → example-api-dev:8080          │
│                                            → example-ui-dev:8080            │
│                                                                              │
│  Auth: Tailscale only (no OAuth2-Proxy for dev services)                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Services

| Service | DEV URL | PRD URL |
|---------|---------|---------|
| example-api | `https://example-api-dev.tail876052.ts.net` | `https://api.untrustedonline.org` |
| example-ui | `https://example-ui-dev.tail876052.ts.net` | `https://app.untrustedonline.org` |

## Auth0 Applications

**Два разных типа приложений:**

| Application | Type | Purpose |
|-------------|------|---------|
| oauth2-proxy | Regular Web Application | Защита ArgoCD, Longhorn (server-side) |
| example-ui-dev | Single Page Application | DEV UI (browser-based) |
| example-ui-prd | Single Page Application | PRD UI (browser-based) |

## Doppler Configuration

| Config | Purpose |
|--------|---------|
| `shared` | Общие секреты (Cloudflare, Auth0 для oauth2-proxy) |
| `dev` | DEV environment (Doppler project branch) |
| `prd` | PRD environment |

## Documentation

1. [01-setup.md](01-setup.md) - Quick start guide
2. [02-auth0-spa.md](02-auth0-spa.md) - Auth0 SPA configuration
3. [03-spring-boot-proxy.md](03-spring-boot-proxy.md) - Spring Boot behind reverse proxy
4. [04-doppler-secrets.md](04-doppler-secrets.md) - All Doppler secrets reference
5. [05-dev-services.md](05-dev-services.md) - Dev services (Tailscale only, no OAuth2)
