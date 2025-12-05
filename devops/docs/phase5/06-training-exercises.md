# Training Exercises: Velero Backup & Restore

## Prerequisites

```bash
# Verify Velero is running
kubectl get pods -n velero
velero version

# Check backup location
velero backup-location get
```

---

## Exercise 1: Basic Namespace Backup/Restore

**Scenario**: Accidentally deleted deployment, need to restore

### Step 1: Create backup
```bash
velero backup create example-api-dev-backup-1 \
  --include-namespaces example-api-dev \
  --wait
```

### Step 2: Verify backup
```bash
velero backup describe example-api-dev-backup-1
velero backup logs example-api-dev-backup-1
```

### Step 3: Simulate disaster
```bash
# Delete the deployment
kubectl delete deployment example-api-dev -n example-api-dev

# Verify it's gone
kubectl get pods -n example-api-dev
```

### Step 4: Restore
```bash
velero restore create --from-backup example-api-dev-backup-1 --wait
```

### Step 5: Verify
```bash
kubectl get pods -n example-api-dev
# App should be running again
```

---

## Exercise 2: PostgreSQL Database Recovery

**Scenario**: Data corruption/deletion, restore from backup

### Step 1: Check current data
```bash
# Connect to PostgreSQL
kubectl exec -it example-api-main-db-dev-1 -n example-api-dev -- psql -U app

# Count records
SELECT COUNT(*) FROM your_table;
\q
```

### Step 2: Create backup (with PVCs)
```bash
velero backup create example-api-dev-db-backup \
  --include-namespaces example-api-dev \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --default-volumes-to-fs-backup \
  --wait
```

### Step 3: Simulate data loss
```bash
kubectl exec -it example-api-main-db-dev-1 -n example-api-dev -- psql -U app -c "DELETE FROM your_table;"
# Or drop the database
```

### Step 4: Restore
```bash
# Scale down to release PVC
kubectl scale deployment example-api-dev -n example-api-dev --replicas=0

# Restore
velero restore create --from-backup example-api-dev-db-backup --wait

# Scale back up
kubectl scale deployment example-api-dev -n example-api-dev --replicas=1
```

### Step 5: Verify data restored
```bash
kubectl exec -it example-api-main-db-dev-1 -n example-api-dev -- psql -U app -c "SELECT COUNT(*) FROM your_table;"
```

---

## Exercise 3: Selective Restore (ConfigMaps only)

**Scenario**: Grafana dashboards deleted, restore only ConfigMaps

### Step 1: Backup monitoring namespace
```bash
velero backup create monitoring-backup-1 \
  --include-namespaces monitoring \
  --wait
```

### Step 2: Delete specific ConfigMap
```bash
# List Grafana dashboards
kubectl get configmaps -n monitoring -l grafana_dashboard=1

# Delete one
kubectl delete configmap <dashboard-name> -n monitoring
```

### Step 3: Selective restore
```bash
velero restore create --from-backup monitoring-backup-1 \
  --include-resources configmaps \
  --wait
```

### Step 4: Verify
```bash
kubectl get configmaps -n monitoring -l grafana_dashboard=1
# Dashboard ConfigMap should be back
```

---

## Exercise 4: Full Namespace Disaster Recovery

**Scenario**: Entire namespace deleted, full recovery

### Step 1: Backup
```bash
velero backup create monitoring-full-backup \
  --include-namespaces monitoring \
  --default-volumes-to-fs-backup \
  --wait
```

### Step 2: DELETE ENTIRE NAMESPACE (careful!)
```bash
# This will delete everything!
kubectl delete namespace monitoring

# Verify it's gone
kubectl get namespace monitoring
```

### Step 3: Restore namespace
```bash
velero restore create --from-backup monitoring-full-backup --wait
```

### Step 4: Verify
```bash
kubectl get pods -n monitoring
kubectl get pvc -n monitoring

# Check Grafana is accessible
```

---

## Exercise 5: Scheduled Backup Verification

**Scenario**: Verify automated backups are working

### Step 1: List scheduled backups
```bash
velero schedule get
```

### Step 2: Check recent backups
```bash
velero backup get --selector velero.io/schedule-name=<schedule-name>
```

### Step 3: Verify backup contents
```bash
velero backup describe <backup-name> --details
```

### Step 4: Test restore from scheduled backup
```bash
# Create test namespace
kubectl create namespace restore-test

# Restore to test namespace
velero restore create test-restore \
  --from-backup <scheduled-backup-name> \
  --namespace-mappings example-api-dev:restore-test \
  --wait

# Verify
kubectl get pods -n restore-test

# Cleanup
kubectl delete namespace restore-test
```

---

## Useful Commands

```bash
# List all backups
velero backup get

# List all restores
velero restore get

# Delete old backup
velero backup delete <backup-name>

# Check backup storage usage
velero backup-location get

# View backup logs
velero backup logs <backup-name>

# View restore logs
velero restore logs <restore-name>
```

---

## Troubleshooting

### Backup stuck in "InProgress"
```bash
# Check Velero logs
kubectl logs -n velero -l app.kubernetes.io/name=velero

# Check node-agent (for PVC backups)
kubectl logs -n velero -l name=node-agent
```

### Restore fails with PVC errors
```bash
# Delete existing PVC first
kubectl delete pvc <pvc-name> -n <namespace>

# Then restore
velero restore create ...
```

### Partial restore
```bash
# Restore only specific resources
velero restore create --from-backup <backup> \
  --include-resources deployments,services,configmaps
```
