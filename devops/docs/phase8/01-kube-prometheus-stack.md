# kube-prometheus-stack

## Overview

Полный стек мониторинга включающий:
- Prometheus Operator
- Prometheus
- Grafana
- AlertManager
- Node Exporter
- kube-state-metrics

## Installation

### ArgoCD Application

```yaml
# apps/templates/monitoring/kube-prometheus-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kube-prometheus-stack
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "30"
spec:
  sources:
    - repoURL: https://prometheus-community.github.io/helm-charts
      chart: kube-prometheus-stack
      targetRevision: "79.10.0"
      helm:
        valueFiles:
          - $values/helm-values/monitoring/kube-prometheus-stack.yaml
    - repoURL: <infrastructure-repo>
      ref: values
  destination:
    namespace: monitoring
```

## Key Configuration

### Grafana Anonymous Mode

Grafana за oauth2-proxy, поэтому используем anonymous mode:

```yaml
# helm-values/monitoring/kube-prometheus-stack.yaml
grafana:
  grafana.ini:
    auth.anonymous:
      enabled: true
      org_name: Main Org.
      org_role: Admin
    auth:
      disable_login_form: true
```

**Docs**: https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/anonymous-auth

### Loki Datasource

```yaml
grafana:
  additionalDataSources:
    - name: Loki
      type: loki
      url: http://loki.monitoring.svc.cluster.local:3100
      access: proxy
      isDefault: false
```

### ServiceMonitor Discovery

Для обнаружения всех ServiceMonitors в кластере:

```yaml
prometheus:
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
```

### Storage (Longhorn)

```yaml
prometheus:
  prometheusSpec:
    retention: 15d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          resources:
            requests:
              storage: 20Gi

grafana:
  persistence:
    enabled: true
    storageClassName: longhorn
    size: 5Gi

alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: longhorn
          resources:
            requests:
              storage: 2Gi
```

## Protected Services Integration

Добавить в `charts/protected-services/values.yaml`:

```yaml
services:
  grafana:
    enabled: true
    namespace: monitoring
    allowedGroups:
      - infra-admins
      - monitoring-admins
    backend:
      name: kube-prometheus-stack-grafana
      port: 80
```

## Official Docs

- https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack
