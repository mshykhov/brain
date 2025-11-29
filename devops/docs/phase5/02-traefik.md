# Traefik Ingress Controller

Docs: https://doc.traefik.io/traefik/

## Overview

Traefik v3 as main Ingress Controller for public-facing services.

## Configuration

Values file: `manifests/helm-values/traefik.yaml`

Key settings:
- LoadBalancer via MetalLB
- HTTP → HTTPS redirect
- Prometheus metrics enabled
- Dashboard disabled (access via Tailscale)

## Ports

| Port | Purpose |
|------|---------|
| 80 | HTTP (redirects to 443) |
| 443 | HTTPS |
| 9100 | Metrics (internal) |

## Usage

Standard Kubernetes Ingress:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
spec:
  ingressClassName: traefik
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 8080
```

Or Traefik IngressRoute CRD for advanced routing.
