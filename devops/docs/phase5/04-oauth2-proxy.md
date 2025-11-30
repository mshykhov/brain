# oauth2-proxy

Docs: https://oauth2-proxy.github.io/oauth2-proxy/

## Overview

oauth2-proxy работает как authentication middleware для NGINX Ingress.

**Режим:** auth_request (НЕ reverse proxy) - возвращает 202/401 для NGINX.

## Architecture

```
User Request → NGINX Ingress
                    │
                    ▼ auth-url annotation
            ┌───────────────┐
            │ oauth2-proxy  │◄──► Auth0 OIDC
            │ /oauth2/auth  │
            └───────┬───────┘
                    │
            202 OK ─┴─ 401 → redirect to Auth0 login
                    │
                    ▼
            Backend Service
```

## Files

| File | Purpose |
|------|---------|
| `helm-values/network/oauth2-proxy.yaml` | Helm values |
| `helm-values/network/redis.yaml` | Redis for sessions |
| `apps/templates/network/redis.yaml` | ArgoCD App (wave 14) |
| `apps/templates/network/oauth2-proxy.yaml` | ArgoCD App (wave 15) |

## Redis (Session Storage)

oauth2-proxy требует Redis для хранения сессий (особенно с большими OIDC токенами).

```yaml
# helm-values/network/redis.yaml
architecture: standalone

auth:
  enabled: true
  existingSecret: redis-password
  existingSecretPasswordKey: password

master:
  persistence:
    enabled: true
    size: 1Gi
    storageClass: longhorn

  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi
```

## oauth2-proxy Helm Values

```yaml
# helm-values/network/oauth2-proxy.yaml
config:
  # Auth0 OIDC
  clientID: ""  # From ExternalSecret
  clientSecret: ""  # From ExternalSecret
  cookieSecret: ""  # From ExternalSecret

  configFile: |-
    # Provider
    provider = "oidc"
    provider_display_name = "Auth0"
    oidc_issuer_url = "https://YOUR_TENANT.auth0.com/"

    # For NGINX auth_request mode
    reverse_proxy = true
    upstream = "static://202"
    skip_provider_button = true

    # Cookie settings
    cookie_secure = true
    cookie_samesite = "lax"
    cookie_httponly = true
    cookie_expire = "168h"
    cookie_refresh = "1h"

    # Session storage
    session_store_type = "redis"
    redis_connection_url = "redis://:PASSWORD@redis-master.redis.svc.cluster.local:6379"

    # Email domain restriction (optional)
    # email_domains = ["example.com"]

    # Scopes
    scope = "openid profile email"

    # Pass headers to backend
    set_xauthrequest = true
    pass_access_token = true
    pass_authorization_header = true

    # Logging
    standard_logging = true
    auth_logging = true
    request_logging = true

# Use secrets from ExternalSecret
extraEnv:
  - name: OAUTH2_PROXY_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: auth0-credentials
        key: client-id
  - name: OAUTH2_PROXY_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: auth0-credentials
        key: client-secret
  - name: OAUTH2_PROXY_COOKIE_SECRET
    valueFrom:
      secretKeyRef:
        name: auth0-credentials
        key: cookie-secret

ingress:
  enabled: true
  className: nginx
  hosts:
    - internal.tailnet-xxxx.ts.net
  path: /oauth2
  pathType: Prefix

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

## ArgoCD Application

```yaml
# apps/templates/network/oauth2-proxy.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oauth2-proxy
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "15"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: https://oauth2-proxy.github.io/manifests
      chart: oauth2-proxy
      targetRevision: "7.9.0"
      helm:
        valueFiles:
          - $values/helm-values/network/oauth2-proxy.yaml
    - repoURL: {{ .Values.spec.source.repoURL }}
      targetRevision: {{ .Values.spec.source.targetRevision }}
      ref: values
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: oauth2-proxy
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## NGINX Ingress Annotations

Для защиты любого сервиса:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: protected-service
  annotations:
    # Auth URL - internal cluster address
    nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/auth"

    # Sign-in URL - external Tailscale address
    nginx.ingress.kubernetes.io/auth-signin: "https://internal.tailnet-xxxx.ts.net/oauth2/start?rd=$scheme://$host$escaped_request_uri"

    # Pass user info headers to backend
    nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Groups,Authorization"

    # Proxy buffer for large headers
    nginx.ingress.kubernetes.io/proxy-buffer-size: "8k"
spec:
  ingressClassName: nginx
  rules:
    - host: myapp.internal.tailnet-xxxx.ts.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

## Verification

```bash
# Check oauth2-proxy pods
kubectl get pods -n oauth2-proxy

# Check Redis
kubectl get pods -n redis

# Check logs
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy

# Test auth endpoint
curl -v https://internal.tailnet-xxxx.ts.net/oauth2/auth
# Should return 401 if not authenticated

# Test sign-in flow
# Open https://internal.tailnet-xxxx.ts.net/oauth2/start in browser
# Should redirect to Auth0 login
```

## Troubleshooting

### 502 Bad Gateway

1. Check oauth2-proxy is running
2. Check Redis connection
3. Check Auth0 credentials are correct

### Cookie too large

Use Redis session storage (already configured above).

### OIDC discovery failed

1. Check Auth0 domain is correct
2. Check network connectivity to Auth0

```bash
kubectl exec -n oauth2-proxy -it deploy/oauth2-proxy -- \
  curl -v https://YOUR_TENANT.auth0.com/.well-known/openid-configuration
```

Sources:
- https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/openid_connect
- https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/
- https://oauth2-proxy.github.io/oauth2-proxy/configuration/integration/
