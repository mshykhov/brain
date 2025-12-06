# Velero Backup & Restore

Velero бэкапит всё кроме PostgreSQL (CNPG использует свой backup → см. [cnpg-backup.md](cnpg-backup.md))

## Schedules

```bash
velero schedule get
```

| Schedule | Time | Retention | Namespaces |
|----------|------|-----------|------------|
| daily-applications | 02:00 | 7d | example-api-*, example-ui-* |
| daily-monitoring | 02:30 | 7d | monitoring |
| daily-infrastructure | 03:00 | 7d | argocd, oauth2-proxy |
| weekly-full | Sun 04:00 | 30d | all (except system) |

## Backup

### List Backups

```bash
velero backup get
velero backup describe <backup> --details
velero backup logs <backup>
```

### Manual Backup

```bash
# Single namespace
velero backup create my-backup \
  --include-namespaces <ns> \
  --default-volumes-to-fs-backup \
  --wait

# From schedule (uses schedule settings)
velero backup create --from-schedule daily-applications
```

## Restore

### Full Namespace

```bash
velero restore create --from-backup <backup> \
  --include-namespaces <ns> \
  --wait
```

### Specific Resources Only

```bash
velero restore create --from-backup <backup> \
  --include-resources configmaps,secrets \
  --wait
```

### To Different Namespace

```bash
velero restore create --from-backup <backup> \
  --namespace-mappings old-ns:new-ns \
  --wait
```

### Check Restore Status

```bash
velero restore get
velero restore describe <restore>
velero restore logs <restore>
```

## GitOps Restore Flow

После restore ArgoCD автоматически синхронизирует:

```bash
# 1. Restore namespace
velero restore create --from-backup <backup> --include-namespaces <ns> --wait

# 2. ArgoCD detects drift → syncs
# 3. Verify
kubectl get pods -n <ns>
argocd app get <app>
```

## PostgreSQL (CNPG)

Velero **исключает** PostgreSQL PVCs (label `cnpg.io/pvcRole`).

PostgreSQL восстанавливается отдельно через CNPG → см. [cnpg-backup.md](cnpg-backup.md)

## Troubleshooting

```bash
# Velero server logs
kubectl logs -n velero deploy/velero

# Node agent logs (FSB)
kubectl logs -n velero -l name=node-agent

# Backup/restore CRDs
kubectl get backups -n velero
kubectl get restores -n velero
```

## Quick Reference

| Action | Command |
|--------|---------|
| List backups | `velero backup get` |
| Backup details | `velero backup describe <backup> --details` |
| Manual backup | `velero backup create --from-schedule <schedule>` |
| Restore | `velero restore create --from-backup <backup> --wait` |
| List restores | `velero restore get` |
| Schedules | `velero schedule get` |
