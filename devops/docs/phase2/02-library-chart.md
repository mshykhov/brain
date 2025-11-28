# Phase 2: Library Chart

**Docs:** https://helm.sh/docs/topics/library_charts/

## Структура

```
example-deploy/_library/
├── Chart.yaml
└── templates/
    ├── _helpers.tpl      # Стандартные хелперы (name, labels)
    ├── _util.tpl         # Merge utility
    ├── _deployment.tpl   # Base Deployment
    ├── _service.tpl      # Base Service
    └── _serviceaccount.tpl # Base ServiceAccount
```

## Chart.yaml

```yaml
apiVersion: v2
name: example-library
description: A Helm library chart for example services
type: library  # Важно!
version: 0.1.0
```

## Паттерн использования

### 1. В library chart (_deployment.tpl)

```yaml
{{- define "example-library.deployment" -}}
{{- include "example-library.util.merge" (append . "example-library.deployment.tpl") -}}
{{- end -}}

{{- define "example-library.deployment.tpl" -}}
apiVersion: apps/v1
kind: Deployment
# ... базовый шаблон
{{- end -}}
```

### 2. В service chart (deployment.yaml)

```yaml
{{- include "example-library.deployment" (list . "example-api.deployment") -}}
{{- define "example-api.deployment" -}}
# Переопределения (если нужны)
{{- end -}}
```

## Merge Utility

```yaml
{{- define "example-library.util.merge" -}}
{{- $top := first . -}}
{{- $overrides := fromYaml (include (index . 1) $top) | default (dict ) -}}
{{- $tpl := fromYaml (include (index . 2) $top) | default (dict ) -}}
{{- toYaml (merge $overrides $tpl) -}}
{{- end -}}
```

Позволяет сервисам переопределять части базового шаблона.

## Проверка

```bash
cd example-deploy/services/example-api
helm dependency update
helm template . --debug
```
