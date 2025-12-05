# Velero Restore в GitOps окружении

**Velero** - backup всего кроме PostgreSQL PVC.
**CNPG** - PostgreSQL backup в S3 через Barman.

## Как работает исключение PostgreSQL

Velero использует `volumePolicies` с `pvcLabels` для исключения CNPG PVC:

```yaml
# manifests/backup/velero-resource-policies.yaml
volumePolicies:
  - conditions:
      pvcLabels:
        cnpg.io/pvcRole: PG_DATA  # CNPG автоматически ставит этот label
    action:
      type: skip
```

**Источники:**
- [Velero Resource Filtering - pvcLabels](https://velero.io/docs/main/resource-filtering/)
- [CNPG Labels - cnpg.io/pvcRole](https://cloudnative-pg.io/documentation/current/labels_annotations/)

---

## Quick Reference

```bash
# Backups
velero backup get
velero backup describe <name> --details

# Restores
velero restore get
velero restore describe <name>

# Schedules
velero schedule get
velero backup create --from-schedule <name>
```

---

## Restore Single Namespace

```bash
NS=<namespace>
BACKUP=<backup-name>

# 1. Restore (PostgreSQL PVC excluded, CNPG восстановит из S3)
velero restore create --from-backup $BACKUP --include-namespaces $NS --wait

# 2. Verify
kubectl get pods -n $NS
kubectl get pvc -n $NS
kubectl get cluster -n $NS
```

PostgreSQL восстанавливается из S3 через CNPG `bootstrap.recovery`.

---

## CNPG Backup/Restore

См: [cnpg-backup.md](cnpg-backup.md)

---

## Links

- [Velero Resource Filtering](https://velero.io/docs/main/resource-filtering/)
- [Velero FSB Documentation](https://velero.io/docs/main/file-system-backup/)
- [CNPG Labels and Annotations](https://cloudnative-pg.io/documentation/current/labels_annotations/)
- [CNPG Backup Documentation](https://cloudnative-pg.io/documentation/current/backup/)
