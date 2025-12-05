# Velero Training Exercises

Практические упражнения для тренировки backup/restore операций.

## Prerequisites: Install Velero CLI

### Option 1: Homebrew (recommended)

```bash
brew install velero
```

### Option 2: Manual Download

```bash
VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | grep tag_name | cut -d '"' -f 4)
wget https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz
tar -xvf velero-${VERSION}-linux-amd64.tar.gz
sudo mv velero-${VERSION}-linux-amd64/velero /usr/local/bin/
```

### Verify

```bash
velero version
velero backup-location get
```

---

## Exercise 1: Basic Namespace Backup & Restore

**Goal**: Backup single namespace, delete something, restore

```bash
# 1. Check current state
kubectl get pods -n example-api-dev
kubectl get pvc -n example-api-dev

# 2. Create backup
velero backup create example-api-dev-backup \
  --include-namespaces example-api-dev \
  --default-volumes-to-fs-backup \
  --wait

# 3. Verify backup
velero backup describe example-api-dev-backup --details

# 4. Simulate disaster - delete deployment
kubectl delete deployment example-api-dev -n example-api-dev

# 5. Verify it's gone
kubectl get pods -n example-api-dev

# 6. Restore
velero restore create --from-backup example-api-dev-backup --wait

# 7. Verify restored
kubectl get pods -n example-api-dev
velero restore describe <restore-name>
```

---

## Exercise 2: PostgreSQL Data Recovery

**Goal**: Restore database after data deletion

```bash
# 1. Check PostgreSQL pod name
kubectl get pods -n example-api-dev -l cnpg.io/cluster

# 2. Check current data (adjust table name)
kubectl exec -it example-api-main-db-dev-cluster-1 -n example-api-dev \
  -- psql -U app -d app -c "SELECT COUNT(*) FROM your_table;"

# 3. Create backup with volumes
velero backup create db-backup-$(date +%Y%m%d-%H%M) \
  --include-namespaces example-api-dev \
  --default-volumes-to-fs-backup \
  --wait

# 4. Simulate data loss
kubectl exec -it example-api-main-db-dev-cluster-1 -n example-api-dev \
  -- psql -U app -d app -c "DELETE FROM your_table;"

# 5. Scale down app to release DB connections
kubectl scale deployment example-api-dev -n example-api-dev --replicas=0

# 6. Delete PVCs to allow restore
kubectl delete pvc -n example-api-dev -l cnpg.io/cluster

# 7. Restore
velero restore create --from-backup db-backup-YYYYMMDD-HHMM --wait

# 8. Wait for PostgreSQL to start
kubectl get pods -n example-api-dev -w

# 9. Scale app back
kubectl scale deployment example-api-dev -n example-api-dev --replicas=1

# 10. Verify data restored
kubectl exec -it example-api-main-db-dev-cluster-1 -n example-api-dev \
  -- psql -U app -d app -c "SELECT COUNT(*) FROM your_table;"
```

---

## Exercise 3: Selective Restore (ConfigMaps only)

**Goal**: Restore only specific resources

```bash
# 1. Backup monitoring
velero backup create monitoring-backup \
  --include-namespaces monitoring \
  --wait

# 2. List ConfigMaps
kubectl get configmap -n monitoring

# 3. Delete specific ConfigMap
kubectl delete configmap <configmap-name> -n monitoring

# 4. Restore ONLY ConfigMaps
velero restore create --from-backup monitoring-backup \
  --include-resources configmaps \
  --wait

# 5. Verify ConfigMap is back
kubectl get configmap <configmap-name> -n monitoring
```

---

## Exercise 4: Full Namespace Disaster Recovery

**Goal**: Recover entire deleted namespace

```bash
# 1. Backup monitoring namespace
velero backup create monitoring-full-backup \
  --include-namespaces monitoring \
  --default-volumes-to-fs-backup \
  --wait

# 2. Record current state
kubectl get pods -n monitoring > /tmp/before.txt

# 3. DELETE NAMESPACE (CAREFUL!)
kubectl delete namespace monitoring

# 4. Wait for deletion
kubectl get namespace monitoring

# 5. Restore
velero restore create --from-backup monitoring-full-backup --wait

# 6. Compare state
kubectl get pods -n monitoring > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt

# 7. Wait for ArgoCD to reconcile
kubectl get application -n argocd | grep monitoring
```

---

## Exercise 5: Cross-Namespace Clone

**Goal**: Clone prd to staging for testing

```bash
# 1. Backup prd
velero backup create prd-clone-backup \
  --include-namespaces example-api-prd \
  --wait

# 2. Restore to new namespace
velero restore create prd-to-staging \
  --from-backup prd-clone-backup \
  --namespace-mappings example-api-prd:example-api-staging

# 3. Verify
kubectl get pods -n example-api-staging

# 4. Cleanup when done
kubectl delete namespace example-api-staging
```

---

## Exercise 6: Scheduled Backup Verification

**Goal**: Verify automated backups work

```bash
# 1. List schedules
velero schedule get

# 2. Check recent backups from schedule
velero backup get --selector velero.io/schedule-name=<schedule-name>

# 3. Manually trigger schedule
velero backup create --from-schedule <schedule-name>

# 4. Verify storage location
velero backup-location get
```

---

## Useful Commands

```bash
# Backups
velero backup get
velero backup describe <name> --details
velero backup logs <name>
velero backup delete <name>

# Restores
velero restore get
velero restore describe <name>
velero restore logs <name>

# Schedules
velero schedule get
velero backup create --from-schedule <name>

# Troubleshooting
kubectl logs -n velero deployment/velero
kubectl logs -n velero -l name=node-agent
```

---

## kubectl Alternatives (no velero CLI)

### Create Backup

```yaml
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: my-backup
  namespace: velero
spec:
  includedNamespaces:
    - example-api-dev
  defaultVolumesToFsBackup: true
  ttl: 168h0m0s
```

```bash
kubectl apply -f backup.yaml
kubectl get backups -n velero -w
```

### Create Restore

```yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: my-restore
  namespace: velero
spec:
  backupName: my-backup
```

```bash
kubectl apply -f restore.yaml
kubectl get restores -n velero -w
```

---

## DR Checklist

- [ ] BackupStorageLocation is Available
- [ ] Test restore of namespace without PVCs
- [ ] Test restore of namespace with PVCs
- [ ] Document RTO/RPO
