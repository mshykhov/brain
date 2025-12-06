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
# From schedule (recommended - uses schedule settings incl. CNPG exclusion)
velero backup create --from-schedule daily-applications

# Custom backup (CNPG excluded)
velero backup create my-backup \
  --include-namespaces <ns> \
  --resource-policies-configmap velero-resource-policies \
  --default-volumes-to-fs-backup \
  --wait
```

`--resource-policies-configmap` — исключает CNPG PVCs (обязательно для manual backup)

## Restore

```bash
NS=<namespace>
BACKUP=<backup-name>

# Pause ArgoCD
kubectl patch app $NS -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'

# Scale down workloads
kubectl scale -n $NS deployment --all --replicas=0
kubectl scale -n $NS statefulset --all --replicas=0

# Wait for pods to terminate (except CNPG)
kubectl wait -n $NS pod -l '!cnpg.io/cluster' --for=delete --timeout=60s 2>/dev/null || true

# Delete PVCs (except CNPG)
kubectl delete pvc -n $NS -l 'cnpg.io/pvcRole notin (PG_DATA,PG_WAL)'

# Restore
velero restore create --from-backup $BACKUP --include-namespaces $NS --existing-resource-policy=update --wait

# Resume ArgoCD
kubectl patch app $NS -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# Verify
kubectl get pods -n $NS
```

CNPG остаётся нетронутым. Для восстановления PostgreSQL → [cnpg-backup.md](cnpg-backup.md)

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
