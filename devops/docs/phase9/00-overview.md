# Phase 9: Data Layer & Production Deployment

## Overview

Data layer (PostgreSQL, Redis) + production deployment через Cloudflare Tunnel:
- **CloudNativePG** - Kubernetes-native PostgreSQL operator
- **OT Redis Operator** - Kubernetes-native Redis (standalone/sentinel)
- **Doppler** - secrets management для Redis паролей
- **Reloader** - auto-restart при изменении secrets
- **Cloudflare Tunnel** - public access для PRD (Full GitOps)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Production (PRD)                              │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │ Cloudflare  │───▶│ NGINX Ingress│───▶│ example-api-prd   │  │
│  │   Tunnel    │    │              │    │ (2 replicas)      │  │
│  └─────────────┘    └──────────────┘    └─────────┬─────────┘  │
│                                                    │            │
│                                         ┌──────────▼──────────┐ │
│                                         │ Redis Sentinel      │ │
│                                         │ (1 master + 1 rep)  │ │
│                                         └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Development (DEV)                             │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐  │
│  │  Tailscale  │───▶│ NGINX Ingress│───▶│ example-api-dev   │  │
│  │   Service   │    │              │    │ (1 replica)       │  │
│  └─────────────┘    └──────────────┘    └─────────┬─────────┘  │
│                                                    │            │
│                                         ┌──────────▼──────────┐ │
│                                         │ Redis Standalone    │ │
│                                         └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| CloudNativePG | Kubernetes operator для PostgreSQL CRDs |
| OT Redis Operator | Kubernetes operator для Redis CRDs |
| redis-instance chart | Helm chart для Redis instances |
| ExternalSecret | Sync passwords от Doppler |
| Reloader | Auto-restart pods при изменении secrets |
| Cloudflare Tunnel | Public access для PRD services |
| External-DNS | Auto DNS records в Cloudflare |
| StringRedisTemplate | Direct Redis operations с TTL |

## Documentation

1. [Redis Operator](01-redis-operator.md) - OT Redis Operator setup
2. [Redis Secrets](02-redis-secrets.md) - Doppler + ExternalSecret
3. [Reloader](03-reloader.md) - autoReloadAll mode
4. [Auth0 Refresh Tokens](04-auth0-refresh-tokens.md) - offline_access scope
5. [Cloudflare Tunnel](05-cloudflare-tunnel.md) - PRD public access
6. [API Cache](06-api-cache.md) - StringRedisTemplate implementation
7. [Cloudflare GitOps](07-cloudflare-gitops.md) - Full GitOps with External-DNS
8. [CloudNativePG](08-cloudnative-pg.md) - PostgreSQL Operator

## Key Decisions

1. **CloudNativePG vs Bitnami** - operator создаёт CRDs, auto-generated secrets, built-in HA
2. **OT Redis Operator vs Bitnami** - operator создаёт Redis CRDs, лучше интеграция с K8s
3. **Doppler для secrets** - Helm lookup не работает с ArgoCD server-side rendering
4. **Reloader autoReloadAll** - автоматический restart без annotations
5. **Redis master service** - для PRD Sentinel mode, отдельный service для master
6. **Cloudflare locally-managed** - config.yaml в Git вместо Dashboard

## Official Docs

- [CloudNativePG](https://cloudnative-pg.io/documentation/current/)
- [OT Redis Operator](https://redis-operator.opstree.dev/)
- [External Secrets Operator](https://external-secrets.io/)
- [Stakater Reloader](https://github.com/stakater/Reloader)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [External-DNS](https://github.com/kubernetes-sigs/external-dns)
