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

**Рекомендуемый процесс:**

```bash
NS=example-api-dev  # target namespace

# 1. Disable ArgoCD selfHeal
# Option A: by labels (if apps have app/env labels)
argocd app list -l app=example-api,env=dev -o name | \
  xargs -I {} argocd app set {} --sync-policy none

# Option B: by destination namespace (kubectl)
for app in $(kubectl get applications -n argocd -o jsonpath="{range .items[?(@.spec.destination.namespace==\"$NS\")]}{.metadata.name}{'\n'}{end}"); do
  argocd app set $app --sync-policy none
done

# 2. Scale down workloads
kubectl scale deployment --all -n $NS --replicas=0
kubectl scale statefulset --all -n $NS --replicas=0

# 3. Delete PVCs
kubectl delete pvc --all -n $NS

# 4. Restore
velero restore create --from-backup <backup-name> --wait

# 5. Wait for pods
kubectl get pods -n $NS -w

# 6. Enable ArgoCD selfHeal
# Option A: by labels
argocd app list -l app=example-api,env=dev -o name | \
  xargs -I {} argocd app set {} --self-heal

# Option B: by destination namespace
for app in $(kubectl get applications -n argocd -o jsonpath="{range .items[?(@.spec.destination.namespace==\"$NS\")]}{.metadata.name}{'\n'}{end}"); do
  argocd app set $app --self-heal
done
```

### Альтернатива: Удаление ArgoCD Application

```bash
# 1. Delete ArgoCD Application (stops sync)
kubectl delete application <app-name> -n argocd

# 2. Delete namespace
kubectl delete namespace <namespace>

# 3. Restore
velero restore create --from-backup <backup-name> --wait

# 4. Root app recreates Application automatically
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
