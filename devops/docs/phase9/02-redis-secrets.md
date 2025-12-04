# Redis Secrets (Doppler + ExternalSecret)

## Problem

Helm `lookup` функция не работает с ArgoCD server-side rendering:
- ArgoCD рендерит templates на сервере, не имея доступа к cluster
- `randAlphaNum` генерирует новый пароль при каждом sync
- Redis pod сохраняет старый пароль → WRONGPASS error

## Solution

ExternalSecret синхронизирует пароли из Doppler в Kubernetes Secrets.

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Doppler   │────▶│  ExternalSecret  │────▶│  K8s Secret │
│  (source)   │     │   (sync 1h)      │     │  (target)   │
└─────────────┘     └──────────────────┘     └──────┬──────┘
                                                    │
                              ┌─────────────────────┼─────────────────────┐
                              │                     │                     │
                              ▼                     ▼                     ▼
                    ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
                    │  Redis Pod      │   │  API Pod        │   │  Reloader       │
                    │  (reads secret) │   │  (reads secret) │   │  (restarts)     │
                    └─────────────────┘   └─────────────────┘   └─────────────────┘
```

## ExternalSecret Template

```yaml
# charts/redis-instance/templates/external-secret.yaml
{{- if and .Values.auth.enabled .Values.auth.key }}
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ include "redis-instance.fullname" . }}-es
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: {{ .Values.auth.secretStore }}  # doppler-dev or doppler-prd
  target:
    name: {{ include "redis-instance.fullname" . }}
    creationPolicy: Owner
  data:
    - secretKey: {{ .Values.auth.secretKey }}
      remoteRef:
        key: {{ .Values.auth.key }}
{{- end }}
```

## Configuration

### Infrastructure (environment defaults)

```yaml
# helm-values/data/redis-dev-defaults.yaml
auth:
  enabled: true
  secretStore: doppler-dev

# helm-values/data/redis-prd-defaults.yaml
auth:
  enabled: true
  secretStore: doppler-prd
```

### Deploy (per-instance key)

```yaml
# databases/example-api/redis/cache.yaml
auth:
  key: REDIS_EXAMPLE_API_CACHE_PASSWORD
```

## Doppler Setup

Add password to both configs:

| Config | Key | Value |
|--------|-----|-------|
| doppler-dev | REDIS_EXAMPLE_API_CACHE_PASSWORD | `<random-32-chars>` |
| doppler-prd | REDIS_EXAMPLE_API_CACHE_PASSWORD | `<different-random-32-chars>` |

## Verify

```bash
# Check ExternalSecret status
kubectl get externalsecrets -A | grep redis

# Check secret exists
kubectl get secret example-api-cache-prd -n example-api-prd -o jsonpath='{.data.password}' | base64 -d

# Test Redis connection
kubectl exec -n example-api-prd example-api-cache-prd-0 -c example-api-cache-prd -- \
  redis-cli -a "$(kubectl get secret example-api-cache-prd -n example-api-prd -o jsonpath='{.data.password}' | base64 -d)" PING
```

## Troubleshooting

### WRONGPASS Error

1. Check ExternalSecret sync status:
   ```bash
   kubectl get externalsecret -n example-api-prd -o yaml
   ```

2. Verify secret password matches Doppler:
   ```bash
   kubectl get secret example-api-cache-prd -n example-api-prd -o jsonpath='{.data.password}' | base64 -d
   ```

3. Restart Redis and API pods:
   ```bash
   kubectl rollout restart statefulset example-api-cache-prd -n example-api-prd
   kubectl rollout restart deployment example-api-prd -n example-api-prd
   ```
