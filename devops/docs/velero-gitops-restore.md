# Velero Restore в GitOps окружении

**Velero** - backup всего кроме PostgreSQL (PVC excluded by label).
**CNPG** - PostgreSQL backup в S3 через Barman (отдельная настройка).

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

PostgreSQL восстанавливается автоматически из S3 через CNPG `bootstrap.recovery`.

---

## CNPG Backup/Restore

См: [cnpg-backup.md](cnpg-backup.md)

---

## Links

- [Velero Restore Reference](https://velero.io/docs/main/restore-reference/)
- [CNPG Backup Documentation](https://cloudnative-pg.io/documentation/current/backup/)
