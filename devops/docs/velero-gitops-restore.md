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
# Set variables
NS=<namespace>
BACKUP=<backup-name>

# 1. Disable ArgoCD auto-sync (root app to prevent recreation)
kubectl patch application root -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# 2. Delete namespace
kubectl delete namespace $NS --wait=true

# 3. Restore
velero restore create --from-backup $BACKUP --include-namespaces $NS --wait

# 4. Fix CNPG cluster status (if namespace has PostgreSQL)
kubectl get cluster -n $NS -o name | xargs -I {} \
  kubectl patch {} -n $NS --type=merge --subresource=status \
  -p '{"status":{"phase":"Setting up primary","phaseReason":""}}'

# 5. Re-enable ArgoCD auto-sync
kubectl patch application root -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# 6. Verify
kubectl get pods -n $NS
kubectl get pvc -n $NS
kubectl get cluster -n $NS
```

---

## CNPG Cluster Handling

**Velero официально не поддерживается CNPG** ([issue #5912](https://github.com/cloudnative-pg/cloudnative-pg/issues/5912)).

Workaround:
1. CNPG Cluster **исключён из backups** (`excludedNamespaceScopedResources`)
2. После restore ArgoCD создаёт новый Cluster
3. Cluster видит существующий PVC → "unrecoverable" состояние
4. **Решение**: patch status (шаг 3 выше) - сбрасывает состояние и позволяет adopt PVC

---

## DR: Multiple Namespaces

```bash
# 1. Check backup
velero backup get
velero backup describe <backup-name> --details

# 2. Delete namespaces
kubectl delete namespace <ns1> <ns2> <ns3>

# 3. Restore
velero restore create --from-backup <backup-name> \
  --include-namespaces <ns1>,<ns2>,<ns3> --wait

# 4. Fix CNPG clusters
for ns in <ns1> <ns2> <ns3>; do
  kubectl get cluster -n $ns -o name 2>/dev/null | xargs -I {} \
    kubectl patch {} -n $ns --type=merge --subresource=status \
    -p '{"status":{"phase":"Setting up primary","phaseReason":""}}'
done

# 5. Verify
kubectl get pods -A | grep -E "<ns1>|<ns2>|<ns3>"
kubectl get pvc -A | grep -E "<ns1>|<ns2>|<ns3>"
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
