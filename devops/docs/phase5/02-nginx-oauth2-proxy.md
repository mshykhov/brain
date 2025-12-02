# NGINX Ingress + oauth2-proxy

## Архитектура

```
User (Tailscale VPN)
       ↓
Tailscale Ingress (ingressClass: tailscale)
  - argocd → argocd.tail876052.ts.net
  - longhorn → longhorn.tail876052.ts.net
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

## Ключевые решения

### Отдельные Tailscale Ingress per service

Каждый сервис получает свой hostname в Tailscale:
- `argocd.tail876052.ts.net`
- `longhorn.tail876052.ts.net`

Это упрощает Auth0 callback URLs и позволяет независимо управлять доступом.

### NGINX как внутренний роутер

NGINX Ingress Controller работает как ClusterIP (не LoadBalancer). Весь внешний трафик идёт через Tailscale Ingress → NGINX.

### Redis HA для сессий

Production setup использует Redis Sentinel (3 replicas) для хранения сессий oauth2-proxy.

## oauth2-proxy Configuration

### Application Template

`apps/templates/network/oauth2-proxy.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: oauth2-proxy
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "15"
spec:
  sources:
    - repoURL: https://oauth2-proxy.github.io/manifests
      chart: oauth2-proxy
      targetRevision: "9.0.0"
      helm:
        valueFiles:
          - $values/helm-values/network/oauth2-proxy.yaml
        valuesObject:
          config:
            configFile: |
              provider = "oidc"
              provider_display_name = "Auth0"
              oidc_issuer_url = "https://{{ .Values.global.auth0.domain }}/"
              email_domains = ["*"]
              upstreams = ["static://202"]
              reverse_proxy = true
              set_xauthrequest = true
              set_authorization_header = true
              pass_access_token = true
              pass_user_headers = true
              skip_provider_button = true
              cookie_secure = true
              cookie_samesite = "lax"
              cookie_httponly = true
              cookie_csrf_per_request = true
              cookie_csrf_expire = "5m"
              whitelist_domains = [".{{ .Values.global.tailnet }}.ts.net", ".auth0.com"]
              cookie_domains = [".{{ .Values.global.tailnet }}.ts.net"]
              insecure_oidc_allow_unverified_email = true
              oidc_groups_claim = "https://ns/groups"
    - repoURL: {{ .Values.spec.source.repoURL }}
      targetRevision: {{ .Values.spec.source.targetRevision }}
      ref: values
  destination:
    namespace: oauth2-proxy
```

### Helm Values

`helm-values/network/oauth2-proxy.yaml`:

```yaml
# Отключаем default secret env vars
proxyVarsAsSecrets: false

# Кастомные env vars из secrets
extraEnv:
  - name: OAUTH2_PROXY_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: auth0-oidc-credentials
        key: client-id
  - name: OAUTH2_PROXY_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: auth0-oidc-credentials
        key: client-secret
  - name: OAUTH2_PROXY_COOKIE_SECRET
    valueFrom:
      secretKeyRef:
        name: oauth2-proxy-cookie
        key: cookie-secret

# Redis HA для сессий
sessionStorage:
  type: redis
  redis:
    clientType: sentinel
    existingSecret: oauth2-proxy-redis
    passwordKey: redis-password
    sentinel:
      masterName: mymaster
      connectionUrls:
        - "redis://oauth2-proxy-redis-announce-0:26379"
        - "redis://oauth2-proxy-redis-announce-1:26379"
        - "redis://oauth2-proxy-redis-announce-2:26379"

# Redis subchart
redis:
  enabled: true
  replicas: 3
  persistentVolume:
    enabled: true
    storageClass: longhorn

# Production settings
replicaCount: 2
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

### Критические настройки

| Параметр | Значение | Зачем |
|----------|----------|-------|
| `proxyVarsAsSecrets: false` | Отключает default env vars | Используем кастомные secrets |
| `upstreams = ["static://202"]` | auth_request mode | Для NGINX auth-url |
| `oidc_groups_claim = "https://ns/groups"` | Namespaced claim | Auth0 требует namespace |
| `cookie_domains = [".ts.net"]` | Wildcard cookie | SSO между сервисами |
| `whitelist_domains` | ts.net + auth0.com | Разрешённые redirect domains |

## NGINX Ingress Configuration

### Helm Values

`helm-values/network/nginx-ingress.yaml`:

```yaml
controller:
  ingressClassResource:
    name: nginx
    default: true
  service:
    type: ClusterIP
  config:
    use-forwarded-headers: "true"
    proxy-buffer-size: "16k"
```

### Protected Service Ingress

`charts/protected-services/templates/ingresses.yaml`:

```yaml
{{- range $name, $service := .Values.services }}
{{- if $service.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}
  namespace: {{ $service.namespace }}
  annotations:
    {{- $authUrl := $.Values.oauth2Proxy.authUrl }}
    {{- if $service.allowedGroups }}
    {{- $authUrl = printf "%s?allowed_groups=%s" $.Values.oauth2Proxy.authUrl (join "," $service.allowedGroups) }}
    {{- end }}
    nginx.ingress.kubernetes.io/auth-url: {{ $authUrl | quote }}
    nginx.ingress.kubernetes.io/auth-signin: {{ $.Values.oauth2Proxy.authSignin | quote }}
    nginx.ingress.kubernetes.io/auth-response-headers: {{ $.Values.oauth2Proxy.authResponseHeaders | quote }}
    nginx.ingress.kubernetes.io/server-snippet: |
      location = /logout {
        return 302 /oauth2/sign_out?rd=https%3A%2F%2F{{ $.Values.global.auth0.domain }}%2Fv2%2Flogout%3Fclient_id%3D{{ $.Values.global.auth0.clientId }}%26returnTo%3Dhttps%253A%252F%252F$host;
      }
spec:
  ingressClassName: nginx
  rules:
    - host: {{ $name }}.{{ $.Values.global.tailnet }}.ts.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ $service.backend.name }}
                port:
                  number: {{ $service.backend.port }}
{{- end }}
{{- end }}
```

## Ingress Auth Annotations

```yaml
annotations:
  # Auth check URL (с группами)
  nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/auth?allowed_groups=infra-admins"

  # Redirect для login
  nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"

  # Headers для backend
  nginx.ingress.kubernetes.io/auth-response-headers: "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Groups"
```

## Logout Flow

Logout делает redirect chain:
1. `/logout` → oauth2-proxy sign_out
2. oauth2-proxy → Auth0 /v2/logout
3. Auth0 → return to original host

Server snippet в ingress:
```nginx
location = /logout {
  return 302 /oauth2/sign_out?rd=https%3A%2F%2Fauth0-domain%2Fv2%2Flogout%3Fclient_id%3DXXX%26returnTo%3Dhttps%253A%252F%252F$host;
}
```

## Sync Waves

| Wave | Component |
|------|-----------|
| 5 | Credentials (secrets) |
| 10 | Tailscale Operator |
| 12 | NGINX Ingress Controller |
| 15 | oauth2-proxy |
| 17 | Protected Services (ingresses) |

## Troubleshooting

### 502 Bad Gateway

```bash
# Check oauth2-proxy is running
kubectl get pods -n oauth2-proxy

# Check service name in auth-url
kubectl get svc -n oauth2-proxy
```

### Redirect Loop

- Cookie domain не совпадает с host
- Clear browser cookies
- Проверь `cookie_domains` в config

### 401 after login

- Callback URL в Auth0 не совпадает
- Проверь oauth2-proxy logs

### Groups не работают

- Проверь Auth0 Action deployed
- Проверь `oidc_groups_claim = "https://ns/groups"`
- Проверь `allowed_groups` spelling

## Следующий шаг

[03-auth0-setup.md](03-auth0-setup.md) — настройка Auth0
