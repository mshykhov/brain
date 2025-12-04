# Cloudflare Tunnel - PRD Public Access

## Overview

PRD services доступны публично через Cloudflare Tunnel → NGINX Ingress.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                 │
│                            │                                     │
│                            ▼                                     │
│                   ┌─────────────────┐                           │
│                   │   Cloudflare    │                           │
│                   │   (DNS + CDN)   │                           │
│                   └────────┬────────┘                           │
│                            │                                     │
│                            ▼                                     │
│                   ┌─────────────────┐                           │
│                   │  cloudflared    │ (Cloudflare Tunnel)       │
│                   │  (in cluster)   │                           │
│                   └────────┬────────┘                           │
│                            │                                     │
│                            ▼                                     │
│                   ┌─────────────────┐                           │
│                   │  NGINX Ingress  │ (Load Balancer)           │
│                   │  (ClusterIP)    │                           │
│                   └────────┬────────┘                           │
│                            │                                     │
│              ┌─────────────┼─────────────┐                      │
│              ▼             ▼             ▼                      │
│      ┌───────────┐  ┌───────────┐  ┌───────────┐               │
│      │ API Pod 1 │  │ API Pod 2 │  │ UI Pod    │               │
│      └───────────┘  └───────────┘  └───────────┘               │
└─────────────────────────────────────────────────────────────────┘
```

## Why NGINX Ingress?

Cloudflare Tunnel использует connection pooling:
- Держит persistent HTTP/2 connections
- Все requests идут через одно соединение
- K8s Service round-robin не работает (single TCP connection)

**Solution**: NGINX Ingress как промежуточный load balancer.

## Configuration

### Protected Services Chart

```yaml
# charts/protected-services/values.yaml
services:
  example-api-prd:
    enabled: true
    oauth2: false
    tailscale: false        # Disable Tailscale
    cloudflare: true        # Enable Cloudflare
    cloudflareHost: "api.untrustedonline.org"
    namespace: example-api-prd
    backend:
      name: example-api-prd
      port: 8080

  example-ui-prd:
    enabled: true
    oauth2: false
    tailscale: false
    cloudflare: true
    cloudflareHost: "untrustedonline.org"
    namespace: example-ui-prd
    backend:
      name: example-ui-prd
      port: 8080
```

### Cloudflare Dashboard

Tunnel → Public Hostnames:

| Hostname | Service |
|----------|---------|
| api.untrustedonline.org | http://nginx-ingress-controller.nginx-ingress:80 |
| untrustedonline.org | http://nginx-ingress-controller.nginx-ingress:80 |

## Load Balancing

С NGINX Ingress:
- Cloudflare Tunnel → NGINX Ingress (single connection OK)
- NGINX Ingress → API Pods (proper round-robin)

Requests распределяются между pods равномерно.

## Access Patterns

| Environment | Access | Auth |
|-------------|--------|------|
| DEV | Tailscale VPN | oauth2-proxy (optional) |
| PRD | Public Internet | Auth0 (in-app) |

## Official Docs

- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)
