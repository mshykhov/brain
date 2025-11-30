# Traefik Ingress Controller

Docs: https://doc.traefik.io/traefik/

## Overview

Traefik v3 для:
- Internal сервисов через Tailscale LoadBalancer (ForwardAuth → oauth2-proxy → Auth0)
- Public сервисов через MetalLB (cert-manager для TLS)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         TAILNET (private)                       │
│                                                                 │
│   Traefik Service (loadBalancerClass: tailscale)               │
│   traefik.tail876052.ts.net                                    │
│   ├── TLS: Tailscale proxy (auto Let's Encrypt)                │
│   ├── Middleware: ForwardAuth → oauth2-proxy → Auth0 (Phase 6) │
│   └── IngressRoutes:                                           │
│       ├── longhorn-internal → Longhorn UI                      │
│       ├── prometheus-internal → Prometheus                     │
│       └── alertmanager-internal → AlertManager                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET (public)                       │
│                                                                 │
│   Traefik Service (MetalLB) - Optional second service          │
│   ├── TLS: cert-manager + Let's Encrypt                        │
│   └── IngressRoutes:                                           │
│       └── api.example.com → example-api                        │
└─────────────────────────────────────────────────────────────────┘
```

## How TLS Works

**Tailscale LoadBalancer:**
1. Tailscale Operator создаёт proxy pod
2. Proxy pod присоединяется к tailnet как `traefik.ts.net`
3. TLS терминируется на proxy (Let's Encrypt через Tailscale)
4. Traefik получает HTTP трафик от proxy

**Преимущество:** Не требует tailscale на хосте, полностью управляется Kubernetes Operator.

## Configuration

Values file: `helm-values/network/traefik.yaml`

```yaml
ingressClass:
  enabled: true
  isDefaultClass: false

providers:
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: true
  kubernetesIngress:
    enabled: false

ports:
  web:
    exposedPort: 80
  websecure:
    exposedPort: 443
    tls:
      enabled: false  # TLS on Tailscale proxy

service:
  type: LoadBalancer
  annotations:
    tailscale.com/hostname: "traefik"
  spec:
    loadBalancerClass: tailscale
```

## Files

| File | Purpose |
|------|---------|
| `helm-values/network/traefik.yaml` | Helm values |
| `apps/templates/network/traefik.yaml` | ArgoCD Application (wave 12) |

## Verification

```bash
# Check Traefik pod
kubectl get pods -n traefik

# Check service got Tailscale IP
kubectl get svc -n traefik traefik

# Check in Tailscale admin
# https://login.tailscale.com/admin/machines
# Should see: traefik.tail876052.ts.net
```

## IngressRoute Example

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: longhorn-internal
  namespace: traefik
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`longhorn.tail876052.ts.net`)
      kind: Rule
      services:
        - name: longhorn-frontend
          namespace: longhorn-system
          port: 80
```

## Next Steps

- Phase 6: oauth2-proxy + Middleware для ForwardAuth
- Public service (optional): MetalLB + cert-manager
