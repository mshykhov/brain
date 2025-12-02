# ServiceMonitor for Applications

## Overview

ServiceMonitor - CRD от Prometheus Operator для автоматического обнаружения endpoints для scrape.

## Spring Boot Setup

### Dependencies

```kotlin
// build.gradle.kts
dependencies {
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("io.micrometer:micrometer-registry-prometheus")
}
```

### Configuration

```yaml
# application.yaml
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus,info
```

### Endpoint

```
GET /actuator/prometheus
```

## Library Chart Template

```yaml
# _library/templates/_servicemonitor.tpl
{{- define "library.servicemonitor" -}}
{{- if .Values.serviceMonitor.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "library.fullname" . }}
  labels:
    {{- include "library.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "library.selectorLabels" . | nindent 6 }}
  endpoints:
    - port: http
      path: {{ .Values.serviceMonitor.path | default "/actuator/prometheus" }}
      interval: {{ .Values.serviceMonitor.interval | default "30s" }}
      scrapeTimeout: {{ .Values.serviceMonitor.scrapeTimeout | default "10s" }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
{{- end }}
{{- end }}
```

## Service Chart Usage

### Template

```yaml
# services/example-api/templates/servicemonitor.yaml
{{- include "library.servicemonitor" . }}
```

### Values

```yaml
# services/example-api/values.yaml
serviceMonitor:
  enabled: true
  path: /actuator/prometheus
  interval: 30s
  scrapeTimeout: 10s
```

## Prometheus Discovery

Для обнаружения всех ServiceMonitors в кластере, в kube-prometheus-stack:

```yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
```

## Verification

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n example-api-dev

# Check Prometheus targets
# В Grafana: Explore → Prometheus → Status → Targets
```

## Official Docs

- https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.ServiceMonitor
- https://docs.spring.io/spring-boot/reference/actuator/endpoints.html
