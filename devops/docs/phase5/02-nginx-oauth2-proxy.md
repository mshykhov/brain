# NGINX Ingress + oauth2-proxy

## Architecture

```
User (Tailscale VPN)
       ↓
Tailscale Service (LoadBalancer class: tailscale)
       ↓
NGINX Ingress Controller (ClusterIP)
       ↓
┌──────────────────────────────────────┐
│  auth-url annotation                 │
│  → oauth2-proxy /oauth2/auth         │
│    ├── 202 OK → proceed to backend   │
│    └── 401 → redirect to Auth0       │
└──────────────────────────────────────┘
       ↓
Backend Service (ArgoCD, Longhorn, etc.)
```

## How It Works

1. User accesses `https://argocd.internal.<tailnet>.ts.net`
2. NGINX checks auth via `auth-url` annotation
3. oauth2-proxy verifies session cookie
4. If no valid session → redirect to Auth0 login
5. After Auth0 login → callback to oauth2-proxy
6. oauth2-proxy sets session cookie
7. NGINX allows request to backend

## Components

### NGINX Ingress Controller
- Chart: `ingress-nginx` v4.12.0
- Service type: ClusterIP (exposed via Tailscale)
- Ingress class: `nginx` (default)

### Tailscale Service
- Exposes NGINX to tailnet
- LoadBalancer with `loadBalancerClass: tailscale`
- Hostname: `internal` → `internal.<tailnet>.ts.net`

### oauth2-proxy
- Chart: `oauth2-proxy` v7.18.0
- Provider: OIDC (Auth0)
- Mode: `upstream = "static://202"` (auth_request mode)
- Session: cookie-based (no Redis)

## Ingress Auth Annotations

```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/auth"
  nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
  nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email"
```

## oauth2-proxy Ingress

Each protected host needs `/oauth2` path routed to oauth2-proxy:

```yaml
rules:
  - host: argocd.internal.<tailnet>.ts.net
    http:
      paths:
        - path: /oauth2
          backend:
            service:
              name: oauth2-proxy
              port: 80
```

## Adding New Protected Service

1. Create Ingress with auth annotations
2. Add `/oauth2` path to oauth2-proxy ingress
3. Add callback URL to Auth0 Application settings

## Troubleshooting

### 502 Bad Gateway
- Check oauth2-proxy is running
- Check service name in auth-url

### Redirect Loop
- Check cookie domain matches host
- Clear browser cookies

### 401 after login
- Check callback URL in Auth0 matches exactly
- Check oauth2-proxy logs for OIDC errors
