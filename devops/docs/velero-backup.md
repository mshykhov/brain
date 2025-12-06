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

### Quick Restore (одиночный namespace)

```bash
NS=<namespace>
BACKUP=<backup-name>

# 1. Pause ArgoCD
kubectl patch app $NS -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'

# 2. Delete workloads and PVCs (except CNPG) - Velero will recreate
kubectl delete deploy,sts,pvc -n $NS -l '!cnpg.io/cluster' --wait=false 2>/dev/null || true
kubectl wait -n $NS pod -l '!cnpg.io/cluster' --for=delete --timeout=120s 2>/dev/null || true

# 3. Restore
velero restore create --from-backup $BACKUP --include-namespaces $NS --wait

# 4. Resume ArgoCD
kubectl patch app $NS -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true}}}}'

# 5. Verify
kubectl get pods -n $NS
```

**Как работает FSB restore:**
- Velero создаёт PVC → новый PV
- Velero создаёт Pod с **init container** (velero-restore-helper)
- Init container ждёт пока kopia восстановит данные
- После FSB main container стартует с данными

**CRITICAL:** ArgoCD должен быть на паузе! Иначе он создаст pod БЕЗ init container.

### Restore Script (полная версия)

```bash
#!/bin/bash
set -euo pipefail

# Velero Restore Script (excludes CNPG)
# Usage: ./velero-restore.sh <namespace> <backup-name> [--dry-run]

NS="${1:?Usage: $0 <namespace> <backup-name> [--dry-run]}"
BACKUP="${2:?Usage: $0 <namespace> <backup-name> [--dry-run]}"
DRY_RUN="${3:-}"
RESTORE_NAME="restore-${NS}-$(date +%Y%m%d-%H%M%S)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }
err() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }

# Validate backup exists
if ! velero backup describe "$BACKUP" &>/dev/null; then
    err "Backup '$BACKUP' not found"
    velero backup get
    exit 1
fi

log "Restoring namespace '$NS' from backup '$BACKUP'"
[[ -n "$DRY_RUN" ]] && log "DRY RUN MODE - no changes will be made"

# Check if namespace has CNPG clusters
CNPG_CLUSTERS=$(kubectl get clusters.postgresql.cnpg.io -n "$NS" -o name 2>/dev/null | wc -l || echo 0)
if [[ "$CNPG_CLUSTERS" -gt 0 ]]; then
    log "Found $CNPG_CLUSTERS CNPG cluster(s) - they will NOT be touched"
fi

# 1. Set BSL to ReadOnly (disaster recovery best practice)
log "Setting backup location to ReadOnly..."
if [[ -z "$DRY_RUN" ]]; then
    kubectl patch backupstoragelocation default -n velero \
        --type merge --patch '{"spec":{"accessMode":"ReadOnly"}}'
fi

# 2. Save and pause ArgoCD sync
ARGOCD_APP=$(kubectl get app -n argocd -o name 2>/dev/null | grep "/$NS$" || true)
ORIGINAL_SYNC=""
if [[ -n "$ARGOCD_APP" ]]; then
    log "Saving original syncPolicy and pausing ArgoCD app: $ARGOCD_APP"
    if [[ -z "$DRY_RUN" ]]; then
        # Save original syncPolicy to restore later
        ORIGINAL_SYNC=$(kubectl get "$ARGOCD_APP" -n argocd -o jsonpath='{.spec.syncPolicy}' 2>/dev/null || echo "null")
        kubectl patch "$ARGOCD_APP" -n argocd --type merge \
            -p '{"spec":{"syncPolicy":null}}'
    fi
fi

# 3. Delete workloads (Velero will recreate with FSB init container)
log "Deleting deployments and statefulsets (Velero will recreate)..."
if [[ -z "$DRY_RUN" ]]; then
    kubectl delete deployment -n "$NS" --all --wait=false 2>/dev/null || true
    # Delete only non-CNPG statefulsets
    for sts in $(kubectl get sts -n "$NS" -o name 2>/dev/null | grep -v "cluster" || true); do
        kubectl delete -n "$NS" "$sts" --wait=false
    done
fi

# 4. Wait for pods to terminate (except CNPG)
log "Waiting for pods to terminate (except CNPG)..."
if [[ -z "$DRY_RUN" ]]; then
    kubectl wait -n "$NS" pod \
        -l '!cnpg.io/cluster' \
        --for=delete \
        --timeout=120s 2>/dev/null || true
fi

# 5. Delete PVCs (except CNPG) - Velero will recreate them with FSB init container
log "Deleting PVCs (except CNPG) - Velero will recreate..."
if [[ -z "$DRY_RUN" ]]; then
    kubectl delete pvc -n "$NS" -l '!cnpg.io/cluster' --wait=false 2>/dev/null || true
    # Wait for PVCs to be deleted
    sleep 5
fi

# 6. Run Velero restore
log "Starting Velero restore: $RESTORE_NAME"
if [[ -z "$DRY_RUN" ]]; then
    velero restore create "$RESTORE_NAME" \
        --from-backup "$BACKUP" \
        --include-namespaces "$NS" \
        --existing-resource-policy=update \
        --wait

    # Check restore status
    RESTORE_STATUS=$(velero restore describe "$RESTORE_NAME" -o json | jq -r '.status.phase')
    if [[ "$RESTORE_STATUS" != "Completed" ]]; then
        err "Restore status: $RESTORE_STATUS"
        velero restore logs "$RESTORE_NAME"
        exit 1
    fi
    log "Restore completed successfully"
fi

# 7. Restore BSL to ReadWrite
log "Setting backup location back to ReadWrite..."
if [[ -z "$DRY_RUN" ]]; then
    kubectl patch backupstoragelocation default -n velero \
        --type merge --patch '{"spec":{"accessMode":"ReadWrite"}}'
fi

# 8. Restore original ArgoCD syncPolicy
if [[ -n "$ARGOCD_APP" ]]; then
    log "Restoring original syncPolicy for: $ARGOCD_APP"
    if [[ -z "$DRY_RUN" ]]; then
        if [[ -n "$ORIGINAL_SYNC" && "$ORIGINAL_SYNC" != "null" ]]; then
            kubectl patch "$ARGOCD_APP" -n argocd --type merge \
                -p "{\"spec\":{\"syncPolicy\":$ORIGINAL_SYNC}}"
        else
            log "No original syncPolicy found, leaving sync disabled"
        fi
    fi
fi

# 9. Wait for pods
log "Waiting for pods to be ready..."
if [[ -z "$DRY_RUN" ]]; then
    sleep 5
    kubectl wait -n "$NS" pod \
        -l '!cnpg.io/cluster' \
        --for=condition=Ready \
        --timeout=300s 2>/dev/null || true
fi

# 10. Summary
log "=== Restore Summary ==="
if [[ -z "$DRY_RUN" ]]; then
    kubectl get pods -n "$NS"
    echo ""
    velero restore describe "$RESTORE_NAME" --details
else
    log "DRY RUN completed - no changes made"
fi

log "Done. CNPG databases were NOT restored - use cnpg-backup.md if needed"
```

### Restore Options

| Flag | Description |
|------|-------------|
| `--existing-resource-policy=update` | Обновить существующие ресурсы (default: skip) |
| `--include-namespaces` | Восстановить только указанные namespace |
| `--exclude-resources` | Исключить типы ресурсов |
| `--namespace-mappings old:new` | Переименовать namespace |
| `--preserve-nodeports` | Сохранить NodePort (для Services) |
| `--selector label=value` | Восстановить только ресурсы с label |

### Restore Order (Velero default)

1. CRDs
2. Namespaces
3. StorageClasses
4. VolumeSnapshotClass/Contents/Snapshots
5. PersistentVolumes
6. PersistentVolumeClaims
7. Secrets, ConfigMaps
8. ServiceAccounts, LimitRanges
9. Pods, ReplicaSets, остальное

### Restore в другой namespace

```bash
velero restore create \
  --from-backup $BACKUP \
  --namespace-mappings old-ns:new-ns \
  --wait
```

### Restore с изменением StorageClass

Создать ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: change-storage-class
  namespace: velero
  labels:
    velero.io/plugin-config: ""
    velero.io/change-storage-class: RestoreItemAction
data:
  old-storage-class: new-storage-class
```

## PostgreSQL (CNPG)

Velero **исключает** PostgreSQL PVCs (label `cnpg.io/pvcRole`).

PostgreSQL восстанавливается отдельно через CNPG → см. [cnpg-backup.md](cnpg-backup.md)

## Disaster Recovery

При полном восстановлении кластера:

```bash
# 1. Установить Velero на новый кластер
# 2. Подключить существующий BSL (R2/S3)
# 3. Проверить доступность бэкапов
velero backup get

# 4. Установить BSL в ReadOnly
kubectl patch backupstoragelocation default -n velero \
    --type merge --patch '{"spec":{"accessMode":"ReadOnly"}}'

# 5. Восстановить infrastructure первым
velero restore create --from-backup daily-infrastructure-<timestamp> --wait

# 6. Восстановить applications
velero restore create --from-backup daily-applications-<timestamp> --wait

# 7. Вернуть BSL в ReadWrite
kubectl patch backupstoragelocation default -n velero \
    --type merge --patch '{"spec":{"accessMode":"ReadWrite"}}'

# 8. Восстановить CNPG отдельно (см. cnpg-backup.md)
```

## Troubleshooting

```bash
# Velero server logs
kubectl logs -n velero deploy/velero

# Node agent logs (FSB)
kubectl logs -n velero -l name=node-agent

# Backup/restore CRDs
kubectl get backups -n velero
kubectl get restores -n velero

# Restore details & errors
velero restore describe <restore> --details
velero restore logs <restore>

# Check warnings/errors
velero restore describe <restore> -o json | jq '.status.warnings, .status.errors'
```

### Common Issues

| Issue | Solution |
|-------|----------|
| PVC already exists | Удалить PVC или использовать `--existing-resource-policy=update` |
| NodePort conflict | Использовать `--preserve-nodeports=false` |
| Resource version conflict | Velero автоматически retry, check logs |
| FSB timeout | Увеличить `--fs-backup-timeout` (default 4h) |

## Quick Reference

| Action | Command |
|--------|---------|
| List backups | `velero backup get` |
| Backup details | `velero backup describe <backup> --details` |
| Manual backup | `velero backup create --from-schedule <schedule>` |
| Restore | `velero restore create --from-backup <backup> --wait` |
| Restore to namespace | `velero restore create --from-backup <backup> --include-namespaces <ns>` |
| Restore logs | `velero restore logs <restore>` |
| List restores | `velero restore get` |
| Schedules | `velero schedule get` |
| Delete restore | `velero restore delete <restore>` |
