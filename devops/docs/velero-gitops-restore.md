# Velero Restore в GitOps окружении

Velero **non-destructive by design** - не перезаписывает существующие ресурсы.
ArgoCD **recreates** ресурсы автоматически при удалении. Это создает race condition.

**Prerequisites:** [velero.md](velero.md), [argocd.md](argocd.md)

---

## Quick Reference

```bash
# Backups
velero backup get
velero backup describe <name> --details
velero backup logs <name>

# Restores
velero restore get
velero restore describe <name>
velero restore logs <name>

# Schedules
velero schedule get
velero backup create --from-schedule <name>
```

---

## Restore Single Namespace

```bash
# 1. Delete namespace
kubectl delete namespace <namespace>

# 2. Restore
velero restore create --from-backup <backup-name> --include-namespaces <namespace> --wait

# 3. Verify
kubectl get pods -n <namespace>
kubectl get pvc -n <namespace>

# ArgoCD automatically recreates Applications and syncs resources
```

---

## CNPG Cluster Handling

CNPG Cluster **исключён из backups** - ArgoCD пересоздаст его, CNPG примет восстановленный PVC.

```yaml
# velero schedule config
excludedNamespaceScopedResources:
  - clusters.postgresql.cnpg.io
```

См: https://github.com/cloudnative-pg/cloudnative-pg/issues/5912

---

## DR: Full Namespace Recovery

```bash
# 1. Check backup
velero backup get
velero backup describe <backup-name> --details

# 2. Delete ArgoCD apps in project
argocd app list -p <project> -o name | xargs argocd app delete -y --wait

# 3. Delete namespaces
kubectl delete namespace <ns1> <ns2> <ns3>

# 4. Wait for deletion
kubectl get namespace | grep <pattern>

# 5. Restore
velero restore create project-restore \
  --from-backup <backup-name> \
  --include-namespaces <ns1>,<ns2>,<ns3> \
  --wait

# 6. Verify
kubectl get pods -A | grep <pattern>
kubectl get pvc -A | grep <pattern>

# 7. ArgoCD root app recreates Applications
kubectl get applications -n argocd | grep <pattern>
```

<details>
<summary>DR: Restore Full Cluster</summary>

**На новом кластере:**

```bash
# 1. Install Velero with same S3 storage
helm install velero vmware-tanzu/velero \
  --namespace velero --create-namespace \
  --set configuration.backupStorageLocation[0].bucket=<bucket> \
  --set configuration.backupStorageLocation[0].config.region=<region> \
  --set configuration.backupStorageLocation[0].config.s3Url=<s3-url>

# 2. Wait for S3 sync
velero backup-location get
velero backup get

# 3. Find latest weekly-full backup
velero backup get --selector velero.io/schedule-name=weekly-full

# 4. Restore
velero restore create full-cluster-restore \
  --from-backup weekly-full-<timestamp> \
  --wait

# 5. Verify
velero restore describe full-cluster-restore --details
kubectl get namespaces
kubectl get pods -A
```

</details>

<details>
<summary>DR: Restore Only PVCs (Data)</summary>

```bash
# 1. Scale down workloads
kubectl scale deployment --all -n <namespace> --replicas=0
kubectl scale statefulset --all -n <namespace> --replicas=0

# 2. Delete CNPG clusters
kubectl delete cluster --all -n <namespace>

# 3. Delete remaining PVCs
kubectl delete pvc --all -n <namespace>

# 4. Restore only PVCs
velero restore create data-restore \
  --from-backup <backup-name> \
  --include-namespaces <namespace> \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --wait

# 5. Scale up (ArgoCD selfHeal will do it)
```

</details>

---

## Checklist

- [ ] Pods Running
- [ ] PVC Bound
- [ ] PostgreSQL data restored
- [ ] Redis data restored
- [ ] ArgoCD Applications synced
- [ ] Ingress working

---

## Links

- [Velero Restore Reference](https://velero.io/docs/main/restore-reference/)
- [CNPG Issue #5912](https://github.com/cloudnative-pg/cloudnative-pg/issues/5912)
