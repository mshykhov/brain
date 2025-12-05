# Velero Training Exercises

Практические упражнения для тренировки backup/restore операций.

## Exercise 1: Basic Backup & Restore (Dev Environment)

### Goal
Создать бэкап dev namespace, удалить данные, восстановить.

### Steps

```bash
# 1. Проверить текущее состояние
kubectl get pods -n dev
kubectl get pvc -n dev

# 2. Создать бэкап
velero backup create dev-training-backup \
  --include-namespaces=dev \
  --wait

# 3. Проверить бэкап
velero backup describe dev-training-backup --details
velero backup logs dev-training-backup

# 4. Симулировать disaster - удалить namespace
kubectl delete namespace dev

# 5. Восстановить
velero restore create dev-restore \
  --from-backup dev-training-backup \
  --wait

# 6. Проверить восстановление
kubectl get pods -n dev
kubectl get pvc -n dev
velero restore describe dev-restore
```

---

## Exercise 2: Selective Restore

### Goal
Восстановить только определённые ресурсы.

### Steps

```bash
# 1. Создать полный бэкап
velero backup create full-selective-test \
  --include-namespaces=dev,monitoring \
  --wait

# 2. Восстановить только deployments и services
velero restore create selective-restore \
  --from-backup full-selective-test \
  --include-resources deployments,services \
  --include-namespaces dev

# 3. Восстановить по label
velero restore create label-restore \
  --from-backup full-selective-test \
  --selector app=example-api

# 4. Проверить что восстановилось
velero restore describe selective-restore --details
```

---

## Exercise 3: Database Backup with Pre-Hooks

### Goal
Бэкап PostgreSQL с использованием pre-backup hooks для consistency.

### Important
CloudNativePG уже делает continuous WAL archiving. Velero бэкапит PVC.

### Steps

```bash
# 1. Проверить PG кластер
kubectl get clusters -n dev
kubectl get pods -n dev -l cnpg.io/cluster=example-api-main-db-dev-cluster

# 2. Создать бэкап с включением PVC
velero backup create db-backup-test \
  --include-namespaces=dev \
  --default-volumes-to-fs-backup=true \
  --wait

# 3. Проверить что volumes включены
velero backup describe db-backup-test --details | grep -A20 "Volumes"
```

---

## Exercise 4: Cross-Namespace Restore

### Goal
Восстановить в другой namespace для тестирования.

### Steps

```bash
# 1. Создать бэкап prod
velero backup create prod-clone-backup \
  --include-namespaces=prd \
  --wait

# 2. Восстановить как staging
velero restore create prod-to-staging \
  --from-backup prod-clone-backup \
  --namespace-mappings prd:staging-test

# 3. Проверить
kubectl get pods -n staging-test

# 4. Cleanup
kubectl delete namespace staging-test
```

---

## Exercise 5: Scheduled Backup Verification

### Goal
Проверить что scheduled backups работают.

### Steps

```bash
# 1. Посмотреть schedules
velero schedule get

# 2. Проверить последние бэкапы от schedule
velero backup get | grep velero-daily
velero backup get | grep velero-weekly

# 3. Запустить schedule вручную
velero backup create --from-schedule velero-daily-critical

# 4. Проверить BackupStorageLocation
velero backup-location get
```

---

## Exercise 6: Disaster Recovery Simulation

### Goal
Полная симуляция восстановления критических сервисов.

### Scenario
Потеряли monitoring namespace.

### Steps

```bash
# 1. Создать свежий бэкап
velero backup create dr-test-backup \
  --include-namespaces=monitoring \
  --wait

# 2. Записать текущее состояние
kubectl get pods -n monitoring > /tmp/before-dr.txt

# 3. Удалить namespace (ОСТОРОЖНО!)
kubectl delete namespace monitoring --wait=false
kubectl delete namespace monitoring --force --grace-period=0

# 4. Дождаться удаления
kubectl get namespace monitoring

# 5. Восстановить
velero restore create dr-restore \
  --from-backup dr-test-backup \
  --wait

# 6. Сравнить
kubectl get pods -n monitoring > /tmp/after-dr.txt
diff /tmp/before-dr.txt /tmp/after-dr.txt

# 7. Проверить ArgoCD sync
kubectl get applications -n argocd | grep monitoring
```

---

## Useful Commands Reference

```bash
# Backups
velero backup get                              # List all backups
velero backup describe <name> --details        # Detailed info
velero backup logs <name>                      # Backup logs
velero backup delete <name>                    # Delete backup

# Restores
velero restore get                             # List all restores
velero restore describe <name>                 # Detailed info
velero restore logs <name>                     # Restore logs

# Schedules
velero schedule get                            # List schedules
velero schedule describe <name>                # Schedule details
velero backup create --from-schedule <name>    # Trigger manually

# Storage
velero backup-location get                     # Check storage status

# Troubleshooting
kubectl logs -n velero deployment/velero       # Velero server logs
kubectl logs -n velero daemonset/node-agent    # Node agent logs
```

---

## Checklist Before Production DR

- [ ] Verify BackupStorageLocation is Available
- [ ] Test restore of small namespace works
- [ ] Test restore of namespace with PVCs works
- [ ] Document RTO (Recovery Time Objective)
- [ ] Document RPO (Recovery Point Objective)
- [ ] Test restore in new cluster (if possible)
