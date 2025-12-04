# Phase 9: Redis Cache & Production Deployment

## Overview

Redis кэширование для микросервисов + production deployment через Cloudflare Tunnel:
- **OT Redis Operator** - Kubernetes-native Redis (standalone/sentinel)
- **Doppler** - secrets management для Redis паролей
- **Reloader** - auto-restart при изменении secrets
- **Cloudflare Tunnel** - public access для PRD

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
| OT Redis Operator | Kubernetes operator для Redis CRDs |
| redis-instance chart | Helm chart для Redis instances |
| ExternalSecret | Sync passwords от Doppler |
| Reloader | Auto-restart pods при изменении secrets |
| Cloudflare Tunnel | Public access для PRD services |

## Key Decisions

1. **OT Redis Operator vs Bitnami** - operator создаёт Redis CRDs, лучше интеграция с K8s
2. **Doppler для secrets** - Helm lookup не работает с ArgoCD server-side rendering
3. **Reloader autoReloadAll** - автоматический restart без annotations
4. **Redis master service** - для PRD Sentinel mode, отдельный service для master

## Official Docs

- [OT Redis Operator](https://redis-operator.opstree.dev/)
- [External Secrets Operator](https://external-secrets.io/)
- [Stakater Reloader](https://github.com/stakater/Reloader)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
