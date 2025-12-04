# Built-in Alerts (kube-prometheus-stack)

## Overview

kube-prometheus-stack includes 100+ pre-configured alerts. Key ones to know:

## Critical Alerts

| Alert | Description | Action |
|-------|-------------|--------|
| `KubeNodeNotReady` | Node not ready for 15m | Check node, SSH, kubelet |
| `KubePodCrashLooping` | Pod restarting >5 times/10m | Check logs, resources |
| `KubeControllerManagerDown` | Controller manager unreachable | Check control plane |
| `KubeSchedulerDown` | Scheduler unreachable | Check control plane |
| `KubeAPIDown` | API server unreachable | Major outage |
| `PrometheusDown` | Prometheus not running | Monitoring broken |
| `AlertmanagerDown` | Alertmanager not running | Alerts not sent |

## Warning Alerts

| Alert | Description | Action |
|-------|-------------|--------|
| `KubePersistentVolumeFillingUp` | PV >85% full, <4h remaining | Expand or cleanup |
| `KubeDeploymentReplicasMismatch` | Desired ≠ current replicas | Check resources, scheduling |
| `KubeStatefulSetReplicasMismatch` | StatefulSet replicas mismatch | Check PVs, scheduling |
| `KubeHpaMaxedOut` | HPA at max replicas | Scale limits or optimize |
| `KubeMemoryOvercommit` | Memory overcommitted | Reduce limits or add nodes |
| `KubeCPUOvercommit` | CPU overcommitted | Reduce limits or add nodes |
| `PrometheusTargetMissing` | Target not scraped | Check service, network |
| `PrometheusRuleFailures` | Rule evaluation failing | Fix PromQL syntax |

## Info Alerts

| Alert | Description | Purpose |
|-------|-------------|---------|
| `Watchdog` | Always firing | Proves alerting works |
| `InfoInhibitor` | Inhibits info alerts | Reduce noise |

## Storage Alerts (Longhorn)

| Alert | Description | Action |
|-------|-------------|--------|
| `LonghornVolumeStatusCritical` | Volume degraded/faulted | Check replicas |
| `LonghornNodeStorageCapacityWarning` | Node storage >70% | Add disks |
| `LonghornDiskError` | Disk has errors | Replace disk |

## Database Alerts (CloudNativePG)

| Alert | Description | Action |
|-------|-------------|--------|
| `CNPGClusterHAWarning` | HA not maintained | Check replicas |
| `CNPGClusterHighConnectionsCritical` | Connections >90% | Increase max_connections |
| `CNPGClusterHighReplicationLag` | Replication lag >10s | Check network, load |
| `CNPGClusterLowDiskSpaceCritical` | Disk <20% free | Expand PV |

## Customizing Alert Severity

Override built-in alert severity in Helm values:

```yaml
# helm-values/monitoring/kube-prometheus-stack.yaml
additionalPrometheusRulesMap:
  custom-overrides:
    groups:
      - name: custom-overrides
        rules:
          # Change Watchdog to info (not firing notification)
          - alert: Watchdog
            expr: vector(1)
            labels:
              severity: info
            annotations:
              summary: "Alerting is working"
```

## Disabling Noisy Alerts

```yaml
# Disable specific alerts
kubeSchedulerAlerting:
  enabled: true
  rules:
    - alert: KubeSchedulerDown
      enabled: false  # Disable this alert

# Or disable entire groups
defaultRules:
  rules:
    kubeScheduler: false  # Disable all scheduler alerts
```

## Custom Alerts

Add custom alerts:

```yaml
additionalPrometheusRulesMap:
  custom-alerts:
    groups:
      - name: custom
        rules:
          # High error rate
          - alert: HighErrorRate
            expr: |
              sum(rate(http_requests_total{status=~"5.."}[5m]))
              / sum(rate(http_requests_total[5m])) > 0.05
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "High error rate detected"
              description: "Error rate is {{ $value | humanizePercentage }}"

          # Pod memory usage
          - alert: PodHighMemory
            expr: |
              container_memory_usage_bytes{container!=""}
              / container_spec_memory_limit_bytes{container!=""} > 0.9
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Pod {{ $labels.pod }} memory >90%"
```

## Alert Runbooks

Many built-in alerts link to runbooks:

- [kubernetes-monitoring/kubernetes-mixin runbooks](https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/main/runbook.md)
- [prometheus-operator runbooks](https://github.com/prometheus-operator/runbooks)

## Verify Alerts

```bash
# List all firing alerts
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | {alertname: .labels.alertname, state: .state}'

# List all rules
kubectl get prometheusrules -A

# Check specific rule
kubectl get prometheusrules -n monitoring kube-prometheus-stack-kubernetes-system -o yaml
```

## Next Steps

→ [04-argocd-notifications.md](04-argocd-notifications.md) - ArgoCD deployment notifications
