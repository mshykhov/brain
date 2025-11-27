# Phase 2: Service Chart

## Структура

```
example-deploy/services/example-api/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── serviceaccount.yaml
```

## Chart.yaml

```yaml
apiVersion: v2
name: example-api
description: A Helm chart for example-api service
type: application
version: 0.1.0
appVersion: "0.0.1"

dependencies:
  - name: example-library
    version: 0.1.0
    repository: file://../../_library
```

## values.yaml

```yaml
replicaCount: 1

image:
  repository: shykhov/example-api
  pullPolicy: IfNotPresent
  tag: ""

serviceAccount:
  create: true
  name: ""

service:
  type: ClusterIP
  port: 80

containerPort: 8080

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Templates

### deployment.yaml

```yaml
{{- include "example-library.deployment" (list . "example-api.deployment") -}}
{{- define "example-api.deployment" -}}
{{- end -}}
```

### service.yaml

```yaml
{{- include "example-library.service" (list . "example-api.service") -}}
{{- define "example-api.service" -}}
{{- end -}}
```

### serviceaccount.yaml

```yaml
{{- include "example-library.serviceaccount" (list . "example-api.serviceaccount") -}}
{{- define "example-api.serviceaccount" -}}
{{- end -}}
```

## Проверка

```bash
cd example-deploy/services/example-api
helm dependency update
helm template .
```
