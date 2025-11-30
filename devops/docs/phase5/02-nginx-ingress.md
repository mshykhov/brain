# NGINX Ingress Controller

Docs: https://kubernetes.github.io/ingress-nginx/

## Overview

NGINX Ingress Controller для internal routing с oauth2-proxy authentication.

**Важно:** Используем `kubernetes.github.io/ingress-nginx`, НЕ `helm.nginx.com/stable`!

## Architecture

```
Tailscale Service (LB class: tailscale)
         │
         ▼
NGINX Ingress Controller (ClusterIP)
         │
         ├── auth-url annotation → oauth2-proxy
         │
         ▼
Backend Services (ArgoCD, Longhorn, Grafana)
```

## Files

| File | Purpose |
|------|---------|
| `helm-values/network/nginx-ingress.yaml` | Helm values |
| `apps/templates/network/nginx-ingress.yaml` | ArgoCD Application (wave 12) |
| `manifests/network/tailscale-nginx-service/` | Tailscale Service manifest |

## Helm Values

```yaml
# helm-values/network/nginx-ingress.yaml
controller:
  # ClusterIP - NOT LoadBalancer!
  # Tailscale Service will expose it
  service:
    type: ClusterIP

  # Enable snippet annotations for oauth2-proxy
  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    use-proxy-protocol: "false"

  # Allow auth annotations
  allowSnippetAnnotations: true

  # Ingress class
  ingressClassResource:
    name: nginx
    enabled: true
    default: true

  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 256Mi
```

## ArgoCD Application

```yaml
# apps/templates/network/nginx-ingress.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nginx-ingress
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "12"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: https://kubernetes.github.io/ingress-nginx
      chart: ingress-nginx
      targetRevision: "4.12.0"
      helm:
        valueFiles:
          - $values/helm-values/network/nginx-ingress.yaml
    - repoURL: {{ .Values.spec.source.repoURL }}
      targetRevision: {{ .Values.spec.source.targetRevision }}
      ref: values
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: ingress-nginx
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## Tailscale Service for NGINX

```yaml
# manifests/network/tailscale-nginx-service/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-ingress-tailscale
  namespace: ingress-nginx
  annotations:
    tailscale.com/hostname: "internal"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/component: controller
  ports:
    - name: https
      port: 443
      targetPort: 443
      protocol: TCP
```

После деплоя будет доступен как `internal.tailnet-xxxx.ts.net`

## Auth Annotations

Для защиты Ingress через oauth2-proxy:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-app
  annotations:
    nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://internal.tailnet-xxxx.ts.net/oauth2/start?rd=$scheme://$host$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Groups"
spec:
  ingressClassName: nginx
  rules:
    - host: app.internal.tailnet-xxxx.ts.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

## Verification

```bash
# Check NGINX pods
kubectl get pods -n ingress-nginx

# Check service
kubectl get svc -n ingress-nginx

# Check Tailscale service
kubectl get svc nginx-ingress-tailscale -n ingress-nginx

# Check in Tailscale admin
# https://login.tailscale.com/admin/machines
# Should see: internal.tailnet-xxxx.ts.net
```

## Why NGINX instead of Traefik?

| Feature | NGINX | Traefik |
|---------|-------|---------|
| auth-url annotation | ✅ Native | ❌ Needs ForwardAuth CRD |
| Documentation | ✅ Extensive | ⚠️ Less examples |
| oauth2-proxy integration | ✅ Well documented | ⚠️ More complex |
| Community examples | ✅ Many | ⚠️ Fewer |

Sources:
- https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
- https://oauth2-proxy.github.io/oauth2-proxy/configuration/integration/
