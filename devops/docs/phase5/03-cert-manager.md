# cert-manager

Docs: https://cert-manager.io/

## Overview

Автоматическое управление TLS сертификатами для **public** сервисов через Let's Encrypt.

**Важно:** Internal сервисы используют Tailscale для TLS (cert-manager не нужен).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET (public)                       │
│                                                                 │
│   Traefik Service (MetalLB)                                    │
│   ├── TLS: cert-manager + Let's Encrypt                        │
│   └── Routes:                                                  │
│       └── api.example.com → example-api                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         TAILNET (private)                       │
│                                                                 │
│   TLS via Tailscale proxy (NO cert-manager needed)             │
│   ├── traefik.ts.net → Traefik                                 │
│   ├── argocd.ts.net → ArgoCD                                   │
│   └── longhorn.ts.net → Longhorn (via Traefik IngressRoute)    │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration

Values file: `helm-values/network/cert-manager.yaml`

```yaml
crds:
  enabled: true
  keep: true

global:
  logLevel: 2

prometheus:
  enabled: false  # Enable in Phase 8
```

## Files

| File | Purpose |
|------|---------|
| `helm-values/network/cert-manager.yaml` | Helm values |
| `apps/templates/network/cert-manager.yaml` | ArgoCD Application (wave 13) |

## ClusterIssuer (создаётся отдельно)

После установки cert-manager, создать ClusterIssuer:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

## Usage with Traefik IngressRoute

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: example-api
  namespace: traefik
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`api.example.com`)
      kind: Rule
      services:
        - name: example-api
          namespace: dev
          port: 8080
  tls:
    secretName: example-api-tls
```

## Verification

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuer status
kubectl get clusterissuer

# Check certificates
kubectl get certificates --all-namespaces
```

## When to Use

| Service Type | TLS Provider |
|-------------|--------------|
| Public (internet) | cert-manager + Let's Encrypt |
| Internal (tailnet) | Tailscale proxy (automatic) |
