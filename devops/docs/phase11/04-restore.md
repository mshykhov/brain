# Restore Procedures

## List Available Backups

```bash
velero backup get
```

## Full Namespace Restore

```bash
# Restore entire namespace
velero restore create --from-backup daily-critical-20241204020000

# Restore to different namespace
velero restore create --from-backup daily-critical-20241204020000 \
  --namespace-mappings monitoring:monitoring-restored
```

## Selective Restore

```bash
# Restore specific resources
velero restore create --from-backup full-backup \
  --include-resources deployments,services,configmaps

# Restore specific labels
velero restore create --from-backup full-backup \
  --selector app=grafana

# Exclude resources
velero restore create --from-backup full-backup \
  --exclude-resources secrets
```

## Restore Status

```bash
# Check restore progress
velero restore get

# Describe restore details
velero restore describe my-restore

# Check restore logs
velero restore logs my-restore
```

## Disaster Recovery Procedure

### 1. New Cluster Setup

```bash
# Install Velero with same config
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.11.1 \
  --bucket velero-backups \
  --backup-location-config region=auto,s3ForcePathStyle=true,s3Url=https://ACCOUNT.r2.cloudflarestorage.com \
  --secret-file ./credentials-velero
```

### 2. Verify Backup Location

```bash
velero backup-location get
velero backup get
```

### 3. Restore Critical Services

```bash
# Restore in order
velero restore create --from-backup latest-backup \
  --include-namespaces argocd

velero restore create --from-backup latest-backup \
  --include-namespaces monitoring
```

### 4. Verify Restore

```bash
kubectl get pods -A
kubectl get pvc -A
```

## Troubleshooting

### Restore Stuck

```bash
# Check velero logs
kubectl logs -n velero deployment/velero

# Check node-agent logs
kubectl logs -n velero daemonset/node-agent
```

### PVC Not Restored

```bash
# Check if CSI driver is installed
kubectl get csidrivers

# Check volume snapshot classes
kubectl get volumesnapshotclasses
```
