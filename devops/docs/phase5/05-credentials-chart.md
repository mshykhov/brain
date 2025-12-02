# Credentials Chart

## Зачем

Централизованный Helm chart для всех ExternalSecrets. Устраняет дублирование и упрощает управление.

## Архитектура

```
apps/values.yaml (non-secrets)     Doppler (secrets)
        ↓                                ↓
    Helm values                   ClusterSecretStore
        ↓                                ↓
    ┌───────────────────────────────────────────┐
    │           Credentials Chart               │
    │                                           │
    │  ┌─────────────────────────────────────┐  │
    │  │ ExternalSecret template:            │  │
    │  │ - clientId from values              │  │
    │  │ - clientSecret from Doppler         │  │
    │  └─────────────────────────────────────┘  │
    └───────────────────────────────────────────┘
                      ↓
              K8s Secrets
```

## Структура

```
charts/credentials/
├── Chart.yaml
├── templates/
│   ├── namespaces.yaml      # oauth2-proxy namespace
│   ├── auth0-oidc.yaml      # ClusterExternalSecret
│   ├── oauth2-proxy.yaml    # ExternalSecrets
│   ├── tailscale.yaml       # ExternalSecret
│   └── dockerhub.yaml       # ClusterExternalSecret
```

## Values

Global values передаются из `apps/values.yaml` через Application:

```yaml
# apps/values.yaml
global:
  tailnet: tail876052
  tailscale:
    clientId: kZUmGQedYj11CNTRL
  auth0:
    domain: dev-xxx.us.auth0.com
    clientId: wsZ3vIm5FlxztPisdo3Jq5BaeJvASZrz
  dockerhub:
    username: shykhovmyron
```

## Templates

### Auth0 OIDC (ClusterExternalSecret)

`templates/auth0-oidc.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterExternalSecret
metadata:
  name: auth0-oidc-credentials
spec:
  externalSecretName: auth0-oidc-credentials
  namespaceSelectors:
    - matchLabels:
        auth0-oidc: "true"
  refreshTime: 5m
  externalSecretSpec:
    secretStoreRef:
      name: doppler-shared
      kind: ClusterSecretStore
    refreshInterval: 5m
    target:
      name: auth0-oidc-credentials
      creationPolicy: Owner
      template:
        metadata:
          labels:
            app.kubernetes.io/part-of: argocd
        data:
          client-id: {{ .Values.global.auth0.clientId | quote }}
          client-secret: "{{`{{ .clientSecret }}`}}"
    data:
      - secretKey: clientSecret
        remoteRef:
          key: AUTH0_CLIENT_SECRET
```

**ClusterExternalSecret** создаёт ExternalSecret во всех namespace с label `auth0-oidc: "true"`.

### OAuth2-Proxy Secrets

`templates/oauth2-proxy.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: oauth2-proxy-cookie
  namespace: oauth2-proxy
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: oauth2-proxy-cookie
    creationPolicy: Owner
  data:
    - secretKey: cookie-secret
      remoteRef:
        key: OAUTH2_PROXY_COOKIE_SECRET
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: oauth2-proxy-redis
  namespace: oauth2-proxy
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: oauth2-proxy-redis
    creationPolicy: Owner
  data:
    - secretKey: redis-password
      remoteRef:
        key: OAUTH2_PROXY_REDIS_PASSWORD
```

### Tailscale OAuth

`templates/tailscale.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: tailscale-oauth
  namespace: tailscale
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: tailscale-oauth
    creationPolicy: Owner
    template:
      data:
        client_id: {{ .Values.global.tailscale.clientId | quote }}
        client_secret: "{{`{{ .clientSecret }}`}}"
  data:
    - secretKey: clientSecret
      remoteRef:
        key: TS_OAUTH_CLIENT_SECRET
```

### DockerHub (ClusterExternalSecret)

`templates/dockerhub.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterExternalSecret
metadata:
  name: dockerhub-credentials
spec:
  externalSecretName: dockerhub-credentials
  namespaceSelectors:
    - matchLabels:
        dockerhub-pull: "true"
  refreshTime: 5m
  externalSecretSpec:
    secretStoreRef:
      name: doppler-shared
      kind: ClusterSecretStore
    refreshInterval: 5m
    target:
      name: dockerhub-credentials
      creationPolicy: Owner
      template:
        type: kubernetes.io/dockerconfigjson
        data:
          .dockerconfigjson: |
            {"auths":{...}}
    data:
      - secretKey: password
        remoteRef:
          key: DOCKERHUB_PULL_TOKEN
```

## Namespace Labels

Для ClusterExternalSecret нужны labels на namespace:

```yaml
# Для oauth2-proxy namespace (создаётся credentials chart)
apiVersion: v1
kind: Namespace
metadata:
  name: oauth2-proxy
  labels:
    auth0-oidc: "true"
```

Для других namespaces добавь label вручную или через ArgoCD:

```bash
kubectl label namespace argocd auth0-oidc=true
kubectl label namespace dev dockerhub-pull=true
kubectl label namespace prd dockerhub-pull=true
```

## Application Template

`apps/templates/core/credentials.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: credentials
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  project: default
  ignoreDifferences:
    - group: external-secrets.io
      kind: ExternalSecret
      jqPathExpressions:
        - .spec.data[].remoteRef.conversionStrategy
        - .spec.data[].remoteRef.decodingStrategy
        - .spec.data[].remoteRef.metadataPolicy
    - group: external-secrets.io
      kind: ClusterExternalSecret
      jqPathExpressions:
        - .spec.externalSecretSpec.data[].remoteRef.conversionStrategy
        - .spec.externalSecretSpec.data[].remoteRef.decodingStrategy
        - .spec.externalSecretSpec.data[].remoteRef.metadataPolicy
  source:
    repoURL: {{ .Values.spec.source.repoURL }}
    targetRevision: {{ .Values.spec.source.targetRevision }}
    path: charts/credentials
    helm:
      valuesObject:
        global:
          tailscale:
            clientId: {{ .Values.global.tailscale.clientId }}
          auth0:
            clientId: {{ .Values.global.auth0.clientId }}
          dockerhub:
            username: {{ .Values.global.dockerhub.username }}
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

**ignoreDifferences** важен — ESO добавляет default values которых нет в source.

## Doppler Secrets

| Key | Описание |
|-----|----------|
| `AUTH0_CLIENT_SECRET` | Auth0 Application Client Secret |
| `OAUTH2_PROXY_COOKIE_SECRET` | Cookie encryption key |
| `OAUTH2_PROXY_REDIS_PASSWORD` | Redis password |
| `TS_OAUTH_CLIENT_SECRET` | Tailscale OAuth Client Secret |
| `DOCKERHUB_PULL_TOKEN` | DockerHub Access Token |

## Pattern: Values vs Secrets

**Правило:** Non-secret data в `apps/values.yaml`, secrets в Doppler.

| Тип | Где хранить | Примеры |
|-----|-------------|---------|
| IDs, usernames | apps/values.yaml | clientId, username |
| Secrets | Doppler | clientSecret, tokens |
| Domains, URLs | apps/values.yaml | auth0.domain, tailnet |

Это позволяет:
1. Видеть non-secret config в git
2. Использовать один Doppler secret в нескольких местах
3. Не дублировать clientId в Doppler и values

## Troubleshooting

### Secret не создаётся

```bash
# Check ExternalSecret status
kubectl get externalsecret -A

# Check ClusterExternalSecret
kubectl get clusterexternalsecret

# Check ClusterSecretStore
kubectl get clustersecretstore
```

### "SecretStore not ready"

- Проверь Doppler Service Token
- Проверь ClusterSecretStore doppler-shared exists

### ArgoCD показывает OutOfSync

- Добавь ignoreDifferences для ESO CRDs
- Используй ServerSideApply=true

## Следующий шаг

[06-protected-services.md](06-protected-services.md) — protected services chart
