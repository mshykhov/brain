# Grafana Alloy - Log Collection

## Overview

Grafana Alloy - OpenTelemetry Collector distribution от Grafana.

> **Note**: Promtail deprecated! Grafana рекомендует Alloy для сбора логов.
> Promtail EOL: November 1, 2025

## Installation

### ArgoCD Application

```yaml
# apps/templates/monitoring/alloy.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: alloy
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "33"
spec:
  sources:
    - repoURL: https://grafana.github.io/helm-charts
      chart: alloy
      targetRevision: "1.4.0"
      helm:
        valueFiles:
          - $values/helm-values/monitoring/alloy.yaml
    - repoURL: <infrastructure-repo>
      ref: values
  destination:
    namespace: monitoring
```

## Key Configuration

### DaemonSet Deployment

```yaml
# helm-values/monitoring/alloy.yaml
controller:
  type: daemonset

alloy:
  mounts:
    varlog: true
    dockercontainers: true
```

### Alloy Config (River syntax)

```yaml
alloy:
  configMap:
    content: |
      // Discover Kubernetes pods
      discovery.kubernetes "pods" {
        role = "pod"
      }

      // Relabel to extract metadata
      discovery.relabel "pod_logs" {
        targets = discovery.kubernetes.pods.targets

        rule {
          source_labels = ["__meta_kubernetes_namespace"]
          target_label  = "namespace"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_name"]
          target_label  = "pod"
        }
        rule {
          source_labels = ["__meta_kubernetes_pod_container_name"]
          target_label  = "container"
        }
      }

      // Tail log files
      loki.source.kubernetes "pod_logs" {
        targets    = discovery.relabel.pod_logs.output
        forward_to = [loki.process.pod_logs.receiver]
      }

      // Process logs
      loki.process "pod_logs" {
        stage.static_labels {
          values = {
            cluster = "k3s-home",
          }
        }
        forward_to = [loki.write.loki.receiver]
      }

      // Send to Loki
      loki.write "loki" {
        endpoint {
          url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
        }
      }
```

## RBAC

Alloy требует RBAC для доступа к Kubernetes API:

```yaml
serviceAccount:
  create: true
rbac:
  create: true
```

## Official Docs

- https://grafana.com/docs/alloy/latest/
- https://grafana.com/docs/alloy/latest/collect/logs-in-kubernetes/
- https://grafana.com/docs/loki/latest/send-data/
