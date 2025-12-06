# CNPG Backup & Restore

## Find Clusters

```bash
# All CNPG clusters
kubectl get clusters.postgresql.cnpg.io -A

# Output example:
# NAMESPACE         NAME                              STATUS   INSTANCES
# example-api-dev   example-api-main-db-dev-cluster   healthy  1
# example-api-prd   example-api-main-db-prd-cluster   healthy  1
```

`<cluster>` = NAME, `<ns>` = NAMESPACE

## Backup

### View Backups

```bash
kubectl get backups -n <ns>
kubectl get scheduledbackups -n <ns>
kubectl cnpg status <cluster> -n <ns>
```

### Manual Backup

```bash
kubectl cnpg backup <cluster> -n <ns>
```

### Check WAL Archiving

```bash
kubectl cnpg psql <cluster> -n <ns> -- -c "SELECT * FROM pg_stat_archiver;"
```

## Restore

### GitOps Flow

1. Добавить recovery config в values файл
2. Push → ArgoCD sync
3. После восстановления — убрать recovery config

### Recovery Config

S3 settings уже в defaults. Добавить в `databases/<service>/postgres/<db>.yaml`:

```yaml
# Restore from latest backup
mode: recovery
recovery:
  clusterName: example-api-main-db-prd-cluster   # source cluster name
```

### PITR (Point-in-Time)

```yaml
mode: recovery
recovery:
  clusterName: example-api-main-db-prd-cluster
  pitrTarget:
    time: "2025-12-06T10:00:00Z"
```

### Disaster Recovery

```bash
# 1. Add recovery config to values (see above)
# 2. Delete cluster (ArgoCD will recreate with recovery)
kubectl delete cluster <cluster> -n <ns>

# 3. Wait for restore, then remove recovery config from values
```

## Troubleshooting

```bash
# Backup status
kubectl describe backup <name> -n <ns>

# Operator logs
kubectl logs -n cnpg-system deploy/cloudnative-pg --tail=100

# Pod logs
kubectl logs <cluster>-1 -n <ns>

# Archiver issues
kubectl cnpg psql <cluster> -n <ns> -- -c "SELECT * FROM pg_stat_archiver;"
```

## Quick Reference

| Action | Command |
|--------|---------|
| Backup | `kubectl cnpg backup <cluster> -n <ns>` |
| Status | `kubectl cnpg status <cluster> -n <ns>` |
| List | `kubectl get backups -n <ns>` |
| Connect | `kubectl cnpg psql <cluster> -n <ns>` |
| Logs | `kubectl cnpg logs cluster <cluster> -n <ns> -f` |
