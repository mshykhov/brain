# ArgoCD с анонимным доступом за oauth2-proxy

## Почему не OIDC напрямую?

Изначально планировалось использовать ArgoCD OIDC интеграцию с Auth0. Проблемы:

1. **Сложность настройки** — ArgoCD требует специфичный OIDC config
2. **Конфликт с oauth2-proxy** — двойная аутентификация
3. **Sync issues** — Reloader + ArgoCD OIDC вызывали бесконечные рестарты

**Решение:** ArgoCD работает в anonymous mode. Доступ контролируется oauth2-proxy на уровне NGINX Ingress.

## Архитектура

```
User → Tailscale VPN → oauth2-proxy (Auth0 check) → ArgoCD (anonymous)
                              ↓
                        Groups validated
                              ↓
                        Access granted
```

## Конфигурация

### argocd-cm.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  url: https://argocd.{{ .Values.global.tailnet }}.ts.net
  users.anonymous.enabled: "true"
```

**Важно:** `url` должен совпадать с Tailscale hostname для корректной работы SSO logout.

### argocd-cmd-params-cm.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
data:
  server.insecure: "true"
  controller.repo.server.timeout.seconds: "300"
  server.repo.server.timeout.seconds: "300"
  reposerver.parallelism.limit: "2"
```

**`server.insecure: "true"`** — TLS termination на уровне Tailscale, не ArgoCD.

### argocd-rbac-cm.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.default: role:admin
```

**`policy.default: role:admin`** — все анонимные пользователи получают admin. Безопасность обеспечивается oauth2-proxy (только пользователи с группой `argocd-admins` пройдут auth check).

## Helm Chart

`charts/argocd-config/Chart.yaml`:

```yaml
apiVersion: v2
name: argocd-config
description: ArgoCD configuration (ConfigMaps for anonymous access)
type: application
version: 2.0.0
```

`charts/argocd-config/values.yaml`:

```yaml
global:
  tailnet: ""  # Passed from parent Application
```

## Application Template

`apps/templates/cicd/argocd-config.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-config
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: default
  source:
    repoURL: {{ .Values.spec.source.repoURL }}
    targetRevision: {{ .Values.spec.source.targetRevision }}
    path: charts/argocd-config
    helm:
      valuesObject:
        global:
          tailnet: {{ .Values.global.tailnet }}
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

## Protected Services Values

В `charts/protected-services/values.yaml`:

```yaml
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
```

## Security Model

```
┌─────────────────────────────────────────────────────────┐
│                    SECURITY LAYERS                       │
├─────────────────────────────────────────────────────────┤
│ 1. Network: Tailscale VPN (private tailnet only)        │
│ 2. Auth: oauth2-proxy + Auth0 (group validation)        │
│ 3. ArgoCD: anonymous (но уже authenticated)             │
└─────────────────────────────────────────────────────────┘
```

Пользователь доходит до ArgoCD UI только если:
1. Он в Tailscale VPN
2. Он прошёл Auth0 login
3. Он имеет требуемую группу (`infra-admins` или `argocd-admins`)

## Почему это безопасно?

1. **Tailscale VPN** — нельзя даже подключиться без членства в tailnet
2. **oauth2-proxy** — проверяет Auth0 login + groups
3. **Anonymous admin** — уже authenticated пользователь, просто без отдельного ArgoCD login

## Альтернативы (не используются)

### ArgoCD OIDC напрямую

```yaml
# НЕ ИСПОЛЬЗУЕТСЯ — конфликтует с oauth2-proxy
data:
  oidc.config: |
    name: Auth0
    issuer: https://auth0-domain/
    clientID: xxx
    clientSecret: $argocd-secret:oidc.auth0.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
```

Проблемы:
- Двойной login (oauth2-proxy + ArgoCD)
- Reloader вызывает sync loops

### Read-only anonymous + OIDC для write

Избыточно сложно для single-user/small-team setup.

## Troubleshooting

### ArgoCD показывает login page

- Проверь `users.anonymous.enabled: "true"` в argocd-cm
- Рестартни argocd-server после изменения

### 403 Forbidden

- Groups не совпадают — проверь Auth0 roles
- Проверь `allowedGroups` в protected-services values

### Sync loop при изменении ConfigMap

- Используй ServerSideApply
- Не используй Reloader для argocd-cm

## Следующий шаг

[05-credentials-chart.md](05-credentials-chart.md) — credentials management
