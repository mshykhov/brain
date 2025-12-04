# Backup Schedules

## Configured Schedules

| Schedule | Cron | TTL | Namespaces |
|----------|------|-----|------------|
| daily-critical | `0 2 * * *` | 7 days | monitoring, argocd |
| weekly-full | `0 3 * * 0` | 30 days | all (except kube-*) |

## Schedule Configuration

```yaml
# helm-values/backup/velero.yaml
schedules:
  daily-critical:
    disabled: false
    schedule: "0 2 * * *"  # 2 AM daily
    template:
      ttl: 168h  # 7 days
      includedNamespaces:
        - monitoring
        - argocd
      snapshotVolumes: true

  weekly-full:
    disabled: false
    schedule: "0 3 * * 0"  # 3 AM Sunday
    template:
      ttl: 720h  # 30 days
      excludedNamespaces:
        - kube-system
        - kube-public
        - kube-node-lease
      snapshotVolumes: true
```

## Manual Backup

```bash
# Backup specific namespace
velero backup create grafana-backup \
  --include-namespaces monitoring \
  --selector app.kubernetes.io/name=grafana

# Backup with volume snapshots
velero backup create full-backup \
  --snapshot-volumes \
  --include-namespaces monitoring,argocd

# Backup without volumes (manifests only)
velero backup create manifests-only \
  --snapshot-volumes=false
```

## Check Backups

```bash
# List all backups
velero backup get

# Describe specific backup
velero backup describe daily-critical-20241204020000

# Check backup logs
velero backup logs daily-critical-20241204020000
```

## Delete Backup

```bash
# Delete specific backup
velero backup delete old-backup

# Delete all backups older than 30 days
velero backup delete --confirm --older-than 720h
```
