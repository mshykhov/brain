# Protected Services Chart

## Зачем

Динамический chart для защиты internal сервисов через Tailscale + NGINX + oauth2-proxy.

## Что создаётся

Для каждого enabled сервиса:
1. **Tailscale Ingress** — hostname в tailnet
2. **NGINX Ingress** — routing с auth annotations
3. **Group-based access** — allowed_groups query param

## Архитектура

```
charts/protected-services/
├── Chart.yaml
├── values.yaml                     # Service definitions
└── templates/
    ├── tailscale-services.yaml     # Tailscale Ingress per service
    └── ingresses.yaml              # NGINX Ingress per service
```

## Values

`charts/protected-services/values.yaml`:

```yaml
# Global (from Application valuesObject)
# global:
#   tailnet: tail876052
#   auth0:
#     domain: xxx.auth0.com
#     clientId: xxx

# oauth2-proxy settings (static)
oauth2Proxy:
  authUrl: "http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/auth"
  authSignin: "https://$host/oauth2/start?rd=$escaped_request_uri"
  authResponseHeaders: "X-Auth-Request-User,X-Auth-Request-Email,X-Auth-Request-Groups"

# Services to protect
services:
  argocd:
    enabled: true
    namespace: argocd
    allowedGroups:
      - infra-admins
      - argocd-admins
    backend:
      name: argocd-server
      port: 80

  longhorn:
    enabled: true
    namespace: longhorn-system
    allowedGroups:
      - infra-admins
      - longhorn-admins
    backend:
      name: longhorn-frontend
      port: 80
```

## Templates

### Tailscale Services

`templates/tailscale-services.yaml`:

```yaml
{{- range $name, $service := .Values.services }}
{{- if $service.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}-tailscale
  namespace: ingress-nginx
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - {{ $name }}
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: nginx-ingress-ingress-nginx-controller
                port:
                  number: 80
{{- end }}
{{- end }}
```

**Как это работает:**
1. `ingressClassName: tailscale` — Tailscale Operator создаёт proxy
2. `tls.hosts: [argocd]` — hostname в tailnet (`argocd.tail876052.ts.net`)
3. Backend → NGINX Ingress Controller

### NGINX Ingresses

`templates/ingresses.yaml`:

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

## Group-Based Authorization

```yaml
# Без групп — любой authenticated user
nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy/oauth2/auth"

# С группами — только users с matching groups
nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy/oauth2/auth?allowed_groups=infra-admins,argocd-admins"
```

oauth2-proxy проверяет пересечение `allowed_groups` с groups из token.

## Application Template

`apps/templates/network/protected-services.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: protected-services
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "17"
spec:
  project: default
  source:
    repoURL: {{ .Values.spec.source.repoURL }}
    targetRevision: {{ .Values.spec.source.targetRevision }}
    path: charts/protected-services
    helm:
      valuesObject:
        global:
          tailnet: {{ .Values.global.tailnet }}
          auth0:
            domain: {{ .Values.global.auth0.domain }}
            clientId: {{ .Values.global.auth0.clientId }}
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

## Добавление нового сервиса

### 1. Добавить в values

```yaml
services:
  grafana:
    enabled: true
    namespace: monitoring
    allowedGroups:
      - infra-admins
      - monitoring-admins
    backend:
      name: grafana
      port: 3000
```

### 2. Добавить Auth0 Callback URLs

В Auth0 Application → Settings:

```
https://grafana.<tailnet>.ts.net/oauth2/callback
```

Allowed Logout URLs:
```
https://grafana.<tailnet>.ts.net
```

### 3. Git push → ArgoCD sync

Новые Tailscale proxy и NGINX ingress создадутся автоматически.

## Traffic Flow

```
1. User → argocd.tail876052.ts.net (Tailscale DNS)
           ↓
2. Tailscale Proxy → nginx-ingress-controller:80
           ↓
3. NGINX matches host: argocd.tail876052.ts.net
           ↓
4. NGINX auth-url → oauth2-proxy/oauth2/auth?allowed_groups=infra-admins
           ↓
5a. 202 OK → proceed to backend (argocd-server:80)
5b. 401 → redirect to Auth0 login
```

## Logout Flow

1. User clicks `/logout`
2. NGINX server-snippet returns 302 → `/oauth2/sign_out?rd=...`
3. oauth2-proxy clears session cookie
4. Redirect to Auth0 `/v2/logout?client_id=...&returnTo=...`
5. Auth0 clears Auth0 session
6. Redirect back to original host

## Troubleshooting

### Tailscale proxy не создаётся

```bash
# Check Tailscale Operator
kubectl get pods -n tailscale

# Check Tailscale Ingress
kubectl get ingress -n ingress-nginx -l ingressClassName=tailscale
```

### 502 от NGINX

```bash
# Check backend service exists
kubectl get svc -n argocd argocd-server

# Check oauth2-proxy is accessible
kubectl exec -n ingress-nginx deploy/nginx-ingress-ingress-nginx-controller -- \
  curl -s http://oauth2-proxy.oauth2-proxy.svc.cluster.local/oauth2/auth
```

### Groups не проверяются

- Проверь `allowedGroups` в values
- Проверь что auth-url содержит `?allowed_groups=...`
- Проверь oauth2-proxy logs на groups claim

### Logout не работает

- Проверь Auth0 Allowed Logout URLs
- Проверь server-snippet encoding (URL encoded)

## Следующий шаг

[07-troubleshooting.md](07-troubleshooting.md) — общий troubleshooting guide
