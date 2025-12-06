# CloudNativePG - Backup & Recovery

## Overview

CNPG использует Barman для бэкапов в S3-compatible storage:
- **Continuous WAL archiving** — point-in-time recovery (PITR)
- **Base backups** — полные снапшоты по расписанию
- **Retention policies** — автоматическая очистка

**Docs:** https://cloudnative-pg.io/documentation/current/backup/

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL Cluster                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Primary    │  │  Replica    │  │  Replica    │          │
│  │  (writes)   │  │  (reads)    │  │  (reads)    │          │
│  └──────┬──────┘  └─────────────┘  └─────────────┘          │
│         │                                                    │
│         ▼                                                    │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  Barman Cloud                        │    │
│  │  • WAL archiving (continuous)                       │    │
│  │  • Base backups (scheduled)                         │    │
│  └───────────────────────┬─────────────────────────────┘    │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           ▼
              ┌─────────────────────────┐
              │   S3 Object Storage     │
              │   (Cloudflare R2)       │
              │                         │
              │  postgresql-backups/    │
              │  ├── <cluster>/         │
              │  │   ├── base/          │
              │  │   └── wals/          │
              │  └── ...                │
              └─────────────────────────┘
```

## Configuration

### Helm Values

```yaml
# helm-values/data/postgres-prd-defaults.yaml
backups:
  enabled: true
  provider: s3
  retentionPolicy: "30d"

  endpointURL: https://<account>.r2.cloudflarestorage.com
  destinationPath: s3://postgresql-backups/

  s3:
    region: auto
    bucket: postgresql-backups
    path: /
    accessKey: ""    # from secret
    secretKey: ""    # from secret

  secret:
    create: false
    name: cnpg-backup-s3    # ExternalSecret

  scheduledBackups:
    - name: daily
      schedule: "0 0 2 * * *"    # 02:00 daily
      backupOwnerReference: self
      method: barmanObjectStore

  data:
    compression: gzip
    jobs: 2

  wal:
    compression: gzip
    maxParallel: 2
```

### Credentials (ExternalSecret)

```yaml
# charts/credentials/templates/cnpg-backup.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterExternalSecret
metadata:
  name: cnpg-backup-credentials
spec:
  namespaceSelector:
    matchLabels:
      tier: application
  externalSecretSpec:
    secretStoreRef:
      kind: ClusterSecretStore
      name: doppler-shared
    target:
      name: cnpg-backup-s3
    data:
      - secretKey: ACCESS_KEY_ID
        remoteRef:
          key: S3_ACCESS_KEY_ID
      - secretKey: ACCESS_SECRET_KEY
        remoteRef:
          key: S3_SECRET_ACCESS_KEY
```

## Operations

### View Backups

```bash
# List backups
kubectl get backups -n <namespace>

# Backup details
kubectl describe backup <name> -n <namespace>

# List scheduled backups
kubectl get scheduledbackups -n <namespace>

# Cluster status (includes backup info)
kubectl cnpg status <cluster> -n <namespace>
```

### Manual Backup

```bash
# Via cnpg plugin
kubectl cnpg backup <cluster> -n <namespace>

# Via kubectl
kubectl apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: manual-backup-$(date +%Y%m%d-%H%M)
  namespace: <namespace>
spec:
  cluster:
    name: <cluster>
  method: barmanObjectStore
EOF
```

### Check WAL Archiving

```bash
# Check archiver status
kubectl cnpg psql <cluster> -n <namespace> -- \
  -c "SELECT * FROM pg_stat_archiver;"

# Check last archived WAL
kubectl cnpg psql <cluster> -n <namespace> -- \
  -c "SELECT last_archived_wal, last_archived_time FROM pg_stat_archiver;"
```

## Recovery Scenarios

### 1. New Cluster from Backup (Clone)

Создание нового кластера из бэкапа (для тестирования, миграции):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: restored-cluster
  namespace: <namespace>
spec:
  instances: 1
  storage:
    size: 10Gi
    storageClass: longhorn

  bootstrap:
    recovery:
      source: source-cluster

  externalClusters:
    - name: source-cluster
      barmanObjectStore:
        destinationPath: s3://postgresql-backups/
        endpointURL: https://<account>.r2.cloudflarestorage.com
        s3Credentials:
          accessKeyId:
            name: cnpg-backup-s3
            key: ACCESS_KEY_ID
          secretAccessKey:
            name: cnpg-backup-s3
            key: ACCESS_SECRET_KEY
```

### 2. Point-in-Time Recovery (PITR)

Восстановление на конкретный момент времени:

```yaml
bootstrap:
  recovery:
    source: source-cluster
    recoveryTarget:
      targetTime: "2025-12-06T10:00:00Z"    # RFC3339
```

Другие варианты recoveryTarget:

```yaml
recoveryTarget:
  # По времени
  targetTime: "2025-12-06T10:00:00Z"

  # По транзакции
  targetXID: "12345678"

  # По LSN
  targetLSN: "0/1234567"

  # По имени restore point
  targetName: "before-migration"

  # Стратегия (inclusive/exclusive)
  targetInclusive: true
```

### 3. In-Place Recovery (Disaster)

Восстановление существующего кластера после катастрофы:

```bash
# 1. Удалить старый кластер
kubectl delete cluster <cluster> -n <namespace>

# 2. Создать новый с тем же именем и recovery bootstrap
kubectl apply -f recovery-cluster.yaml

# 3. ArgoCD синхронизирует автоматически если GitOps
```

### 4. Restore to Different Namespace

```yaml
metadata:
  name: restored-cluster
  namespace: staging    # другой namespace

bootstrap:
  recovery:
    source: prod-cluster
    database: app
    owner: app

externalClusters:
  - name: prod-cluster
    barmanObjectStore:
      serverName: example-api-main-db-prd-cluster    # оригинальное имя
      destinationPath: s3://postgresql-backups/
      # ...
```

## Retention & Cleanup

### Retention Policy

```yaml
backups:
  retentionPolicy: "30d"    # Keep backups for 30 days
```

Форматы:
- `30d` — 30 дней
- `4w` — 4 недели
- `6m` — 6 месяцев

### Manual Cleanup

```bash
# Delete old backups
kubectl delete backup <name> -n <namespace>

# Check S3 usage
aws s3 ls s3://postgresql-backups/ --recursive --summarize
```

## Monitoring

### Prometheus Alerts

CNPG chart включает PrometheusRules:

| Alert | Description |
|-------|-------------|
| `CNPGClusterHAWarning` | HA not achieved |
| `CNPGClusterOffline` | All instances down |
| `CNPGClusterZoneSpreadWarning` | Poor zone distribution |

### Custom Backup Alerts

```yaml
# В prometheusRule
- alert: CNPGBackupFailed
  expr: |
    cnpg_collector_last_available_backup_timestamp < (time() - 86400)
  for: 1h
  labels:
    severity: critical
  annotations:
    summary: "No successful backup in 24h for {{ $labels.cluster }}"
```

### Grafana Dashboard

Import dashboard ID: `20417` (CloudNativePG)

## Troubleshooting

### Backup Not Starting

```bash
# Check scheduled backup
kubectl describe scheduledbackup <name> -n <namespace>

# Check backup pods
kubectl get pods -n <namespace> | grep backup

# Check operator logs
kubectl logs -n cnpg-system deploy/cloudnative-pg --tail=100
```

### WAL Archiving Failed

```bash
# Check archiver status
kubectl cnpg psql <cluster> -n <namespace> -- \
  -c "SELECT * FROM pg_stat_archiver;"

# Check pod logs
kubectl logs <cluster>-1 -n <namespace> | grep -i "wal\|archive"

# Check S3 connectivity
kubectl exec <cluster>-1 -n <namespace> -- \
  curl -I https://<account>.r2.cloudflarestorage.com
```

### Recovery Failed

```bash
# Check recovery cluster status
kubectl describe cluster <cluster> -n <namespace>

# Check pod logs during bootstrap
kubectl logs <cluster>-1 -n <namespace>

# Common issues:
# - Wrong serverName in externalClusters
# - S3 credentials missing or wrong
# - Backup not found (check destinationPath)
```

## Best Practices

1. **Test restores regularly** — минимум раз в месяц
2. **Use PITR for production** — не только base backups
3. **Monitor WAL archiving** — lag должен быть минимальным
4. **Separate buckets** — dev/prd в разных buckets
5. **Encryption at rest** — включить в S3 bucket settings
6. **Cross-region replication** — для DR

## Quick Reference

```bash
# Backup
kubectl cnpg backup <cluster> -n <ns>

# Status
kubectl cnpg status <cluster> -n <ns>

# List backups
kubectl get backups -n <ns>

# Connect to DB
kubectl cnpg psql <cluster> -n <ns>

# Logs
kubectl cnpg logs cluster <cluster> -n <ns> -f
```
