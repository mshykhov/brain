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
│   Traefik Service (MetalLB: 192.168.8.240)                     │
│   ├── TLS: cert-manager + Let's Encrypt                        │
│   └── Routes:                                                  │
│       ├── api-dev.45.112.124.180.nip.io → example-api (dev)    │
│       └── api.45.112.124.180.nip.io → example-api (prd)        │
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
| `manifests/network/cert-manager-issuer/*.yaml` | ClusterIssuers (wave 14) |

## ClusterIssuers

Два ClusterIssuer для разных окружений:

### letsencrypt-staging (для dev)

File: `manifests/network/cert-manager-issuer/letsencrypt-staging.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: myronshykhov95@gmail.com
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

**Staging сервер:**
- Не имеет rate limits
- Сертификаты НЕ доверенные (для тестирования)
- Используется для dev окружения

### letsencrypt-prod (для prd)

File: `manifests/network/cert-manager-issuer/letsencrypt-prod.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: myronshykhov95@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
      - http01:
          ingress:
            ingressClassName: traefik
```

**Production сервер:**
- Имеет rate limits (50 certificates/week)
- Сертификаты доверенные
- Используется для prd окружения

## Usage in example-deploy

Helm values для IngressRoute + Certificate:

### values-dev.yaml

```yaml
ingressRoute:
  enabled: true
  host: "api-dev.45.112.124.180.nip.io"
  entryPoints:
    - websecure
  tls:
    enabled: true
    certManager:
      enabled: true
      issuer: letsencrypt-staging
```

### values-prd.yaml

```yaml
ingressRoute:
  enabled: true
  host: "api.45.112.124.180.nip.io"
  entryPoints:
    - websecure
  tls:
    enabled: true
    certManager:
      enabled: true
      issuer: letsencrypt-prod
```

## Verification

```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuer status
kubectl get clusterissuer
# Both should show Ready: True

# Check certificates
kubectl get certificates --all-namespaces

# Check certificate details
kubectl describe certificate example-api-tls -n dev

# Check ACME challenges (during issuance)
kubectl get challenges --all-namespaces
```

## Troubleshooting

### Certificate not issuing

1. Check ClusterIssuer status:
   ```bash
   kubectl describe clusterissuer letsencrypt-staging
   ```

2. Check Certificate status:
   ```bash
   kubectl describe certificate example-api-tls -n dev
   ```

3. Check ACME challenge:
   ```bash
   kubectl get challenges -A
   kubectl describe challenge <name> -n <namespace>
   ```

4. Ensure port forwarding is configured:
   - Router: 80,443 → 192.168.8.240

## When to Use

| Environment | ClusterIssuer | Certificate Trust |
|-------------|---------------|-------------------|
| dev | letsencrypt-staging | Not trusted (testing) |
| prd | letsencrypt-prod | Trusted |
| internal (tailnet) | Not needed | Tailscale auto-TLS |
