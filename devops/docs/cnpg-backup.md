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

### How Recovery Works

- `bootstrap.recovery` выполняется **только при создании** кластера
- На существующий кластер не влияет
- Для восстановления нужно удалить кластер и создать заново

### GitOps Flow

1. Добавить `mode: recovery` в values
2. `kubectl delete cluster <cluster> -n <ns>`
3. ArgoCD создаёт новый кластер → recovery выполняется
4. Убрать `mode: recovery` из values (cleanup)

### Recovery Config

S3 settings уже в defaults. Добавить в `databases/<service>/postgres/<db>.yaml`:

```yaml
mode: recovery
recovery:
  clusterName: <cluster>   # из kubectl get clusters -A (колонка NAME)
```

### PITR (Point-in-Time)

```yaml
mode: recovery
recovery:
  clusterName: <cluster>
  pitrTarget:
    time: "2025-12-06T10:00:00Z"
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
