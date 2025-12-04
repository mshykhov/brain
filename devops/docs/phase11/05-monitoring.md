# Monitoring & Alerts

## Prometheus Metrics

Velero exposes metrics at `/metrics` endpoint.

### Key Metrics

| Metric | Description |
|--------|-------------|
| `velero_backup_total` | Total backups attempted |
| `velero_backup_success_total` | Successful backups |
| `velero_backup_failure_total` | Failed backups |
| `velero_backup_last_status` | Last backup status (1=success, 0=failed) |
| `velero_backup_last_successful_timestamp` | Timestamp of last success |
| `velero_restore_total` | Total restores |

## Configured Alerts

```yaml
# helm-values/backup/velero.yaml
prometheusRule:
  spec:
    - alert: VeleroBackupFailed
      expr: velero_backup_last_status{schedule!=""} == 0
      for: 15m
      labels:
        severity: critical

    - alert: VeleroBackupPartiallyFailed
      expr: velero_backup_last_status{schedule!=""} == 2
      for: 15m
      labels:
        severity: warning

    - alert: VeleroNoRecentBackup
      expr: (time() - velero_backup_last_successful_timestamp{schedule!=""}) > 90000
      for: 1h
      labels:
        severity: critical
```

## Grafana Dashboard

Import dashboard ID: **16829** (Velero Stats)

Or use PromQL queries:

```promql
# Backup success rate (last 24h)
sum(rate(velero_backup_success_total[24h])) /
sum(rate(velero_backup_total[24h])) * 100

# Last backup age (hours)
(time() - velero_backup_last_successful_timestamp) / 3600

# Backup duration
velero_backup_duration_seconds
```

## Verification Commands

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n velero

# Check PrometheusRule
kubectl get prometheusrule -n velero

# Test metrics endpoint
kubectl port-forward -n velero svc/velero 8085:8085
curl localhost:8085/metrics | grep velero_backup
```

## Telegram Notifications

Backup alerts go through Alertmanager → Telegram:
- **Critical**: Backup failed
- **Warning**: Partial failure
- **Critical**: No backup in 25 hours
