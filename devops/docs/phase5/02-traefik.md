# Traefik Ingress Controller

Docs: https://doc.traefik.io/traefik/

## Overview

Traefik v3 с dual-service архитектурой:
- **Primary Service (MetalLB):** Публичный доступ через интернет
- **Additional Service (Tailscale):** Внутренний доступ через tailnet

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET (public)                       │
│                                                                 │
│   Traefik Primary Service (MetalLB)                            │
│   IP: 192.168.8.240                                            │
│   ├── HTTP :80 → redirect to HTTPS                             │
│   ├── HTTPS :443 → TLS via cert-manager + Let's Encrypt        │
│   └── Routes:                                                  │
│       ├── api-dev.45.112.124.180.nip.io → example-api (dev)    │
│       └── api.45.112.124.180.nip.io → example-api (prd)        │
│                                                                 │
│   Prerequisites:                                               │
│   - Router port forwarding: 80,443 → 192.168.8.240             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         TAILNET (private)                       │
│                                                                 │
│   Traefik Additional Service (Tailscale)                       │
│   traefik.ts.net                                               │
│   ├── TLS: Tailscale proxy (auto Let's Encrypt)                │
│   ├── Middleware: ForwardAuth → oauth2-proxy → Auth0 (Phase 6) │
│   └── Routes:                                                  │
│       ├── longhorn-internal → Longhorn UI                      │
│       ├── prometheus-internal → Prometheus                     │
│       └── alertmanager-internal → AlertManager                 │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

Values file: `helm-values/network/traefik.yaml`

```yaml
ingressClass:
  enabled: true
  isDefaultClass: true

providers:
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: true
    allowExternalNameServices: true
  kubernetesIngress:
    enabled: true
    publishedService:
      enabled: true

# Entrypoints
ports:
  web:
    port: 8000
    expose:
      default: true
      internal: true
    exposedPort: 80
    protocol: TCP
    # Traefik v34+ syntax for HTTP→HTTPS redirect
    redirections:
      entryPoint:
        to: websecure
        scheme: https
        permanent: true
  websecure:
    port: 8443
    expose:
      default: true
      internal: true
    exposedPort: 443
    protocol: TCP
    tls:
      enabled: true

# Primary Service: MetalLB (public access)
service:
  enabled: true
  type: LoadBalancer
  # Additional Service: Tailscale (internal access)
  additionalServices:
    internal:
      type: LoadBalancer
      annotations:
        tailscale.com/hostname: "traefik"
      labels:
        traefik-service-label: internal
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

# Check services
kubectl get svc -n traefik
# Should see:
# - traefik (192.168.8.240 from MetalLB)
# - traefik-internal (Tailscale IP)

# Check in Tailscale admin
# https://login.tailscale.com/admin/machines
# Should see: traefik.ts.net
```

## IngressRoute with cert-manager

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-api
  namespace: dev
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`api-dev.45.112.124.180.nip.io`)
      kind: Rule
      services:
        - name: example-api
          port: 8080
  tls:
    secretName: example-api-tls
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-api-tls
  namespace: dev
spec:
  secretName: example-api-tls
  issuerRef:
    name: letsencrypt-staging  # or letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - api-dev.45.112.124.180.nip.io
```

## nip.io Domain

Для публичного доступа без покупки домена используется nip.io:
- Формат: `<subdomain>.<public-ip>.nip.io`
- Dev: `api-dev.45.112.124.180.nip.io`
- Prd: `api.45.112.124.180.nip.io`

nip.io автоматически резолвит в указанный IP.
