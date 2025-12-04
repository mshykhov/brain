# Reloader - Auto Restart on Secret Changes

## Overview

Stakater Reloader автоматически рестартит pods когда их Secrets/ConfigMaps изменяются.

## Configuration

```yaml
# helm-values/core/reloader.yaml
reloader:
  autoReloadAll: true  # No annotations needed!
  deployment:
    resources:
      requests: { cpu: 10m, memory: 32Mi }
      limits: { cpu: 50m, memory: 64Mi }
```

## autoReloadAll Mode

С `autoReloadAll: true`:
- Reloader следит за ВСЕМИ Secrets/ConfigMaps
- Автоматически рестартит workloads которые их используют
- **Аннотации НЕ нужны** на Deployments/StatefulSets

## How It Works

1. ExternalSecret синхронизирует новый пароль из Doppler
2. K8s Secret обновляется
3. Reloader обнаруживает изменение
4. Reloader находит все pods которые используют этот Secret
5. Reloader делает rollout restart

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Doppler   │────▶│   Secret    │────▶│  Reloader   │
│  (change)   │     │  (updated)  │     │  (watches)  │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                           ┌───────────────────┼───────────────────┐
                           │                   │                   │
                           ▼                   ▼                   ▼
                   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
                   │ Redis STS     │   │ API Deploy    │   │ Other...      │
                   │ (restart)     │   │ (restart)     │   │ (restart)     │
                   └───────────────┘   └───────────────┘   └───────────────┘
```

## Why autoReloadAll?

OT Redis Operator не поддерживает `podAnnotations` в CRD:
- Нельзя добавить `reloader.stakater.com/auto: "true"` через chart
- С `autoReloadAll: true` это не нужно

## Removed Annotations

С включённым `autoReloadAll` удалены все ручные аннотации из:
- `helm-values/network/tailscale-operator.yaml`
- `helm-values/network/oauth2-proxy.yaml`
- `helm-values/network/nginx-ingress.yaml`

## Official Docs

- [Stakater Reloader](https://github.com/stakater/Reloader)
- [Auto Reload All](https://github.com/stakater/Reloader#auto-reload-all)
