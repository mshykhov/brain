# Velero Restore в GitOps окружении

Документация по backup/restore для окружения с ArgoCD.

**Prerequisites:** [velero.md](velero.md), [argocd.md](argocd.md)

---

## Проблема

Velero **non-destructive by design** - не перезаписывает существующие ресурсы.
ArgoCD **recreates** ресурсы автоматически при удалении.

Это создает race condition при restore.

---

## Backup

### Single Namespace

```bash
velero backup create example-api-dev-backup \
  --include-namespaces example-api-dev \
  --default-volumes-to-fs-backup \
  --wait
```

### Multiple Namespaces (Project)

```bash
velero backup create data-backup \
  --include-namespaces example-api-dev,example-api-prd,example-ui-dev,example-ui-prd \
  --default-volumes-to-fs-backup \
  --wait
```

### By Label

```bash
velero backup create apps-backup \
  --selector tier=application \
  --default-volumes-to-fs-backup \
  --wait
```

### Full Cluster

```bash
velero backup create full-backup \
  --exclude-namespaces kube-system,kube-public,kube-node-lease,velero \
  --default-volumes-to-fs-backup \
  --wait
```

---

## Restore Single Namespace (с PVC данными)

### Вариант 1: Через Git (рекомендуется)

**1. Отключи selfHeal в Git репо:**

```yaml
# apps/values.yaml или application manifest
syncPolicy:
  automated:
    prune: true
    selfHeal: false  # временно отключить
```

**2. Push и дождись ArgoCD sync**

**3. Scale down workloads:**

```bash
kubectl scale deployment example-api-dev -n example-api-dev --replicas=0
kubectl scale statefulset example-api-cache-dev -n example-api-dev --replicas=0
```

**4. Удали PVC:**

```bash
# Для CNPG - удали cluster (он удалит PVC)
kubectl delete cluster example-api-main-db-dev-cluster -n example-api-dev

# Или напрямую PVC
kubectl delete pvc example-api-main-db-dev-cluster-1 -n example-api-dev
kubectl delete pvc example-api-cache-dev-example-api-cache-dev-0 -n example-api-dev
```

**5. Restore:**

```bash
velero restore create --from-backup example-api-dev-backup --wait
```

**6. Включи selfHeal обратно в Git и push**

### Вариант 2: Удаление ArgoCD Application

```bash
# 1. Удали ArgoCD Application (останавливает sync)
kubectl delete application example-api-dev -n argocd

# 2. Удали namespace
kubectl delete namespace example-api-dev

# 3. Restore
velero restore create --from-backup example-api-dev-backup --wait

# 4. Root app пересоздаст Application автоматически
```

### Вариант 3: Полное удаление namespace

```bash
# 1. Удали namespace (ArgoCD может пересоздать - race condition!)
kubectl delete namespace example-api-dev

# 2. Сразу restore
velero restore create --from-backup example-api-dev-backup --wait
```

---

## Restore Project (несколько namespaces)

```bash
# 1. Удали Applications
kubectl delete application example-api-dev example-api-prd -n argocd

# 2. Удали namespaces
kubectl delete namespace example-api-dev example-api-prd

# 3. Restore
velero restore create --from-backup data-backup --wait
```

---

## Restore Monitoring

```bash
# 1. Удали Application
kubectl delete application kube-prometheus-stack loki -n argocd

# 2. Удали namespace
kubectl delete namespace monitoring

# 3. Restore (включает Prometheus data, Grafana dashboards, AlertManager)
velero restore create --from-backup monitoring-backup --wait
```

---

## Restore Full Cluster

```bash
# 1. Удали root Application (останавливает весь GitOps)
kubectl delete application root -n argocd

# 2. Restore
velero restore create --from-backup full-backup --wait

# 3. Пересоздай root app
kubectl apply -f bootstrap/root-app.yaml
```

---

## Полезные флаги

```bash
# Restore в другой namespace
velero restore create --from-backup my-backup \
  --namespace-mappings old-ns:new-ns

# Restore только определенные ресурсы
velero restore create --from-backup my-backup \
  --include-resources configmaps,secrets

# Исключить ресурсы
velero restore create --from-backup my-backup \
  --exclude-resources persistentvolumeclaims
```

---

## Проверка

```bash
# Статус restore
velero restore describe <restore-name>
velero restore logs <restore-name>

# Проверь pods
kubectl get pods -n <namespace> -w

# Проверь PVC
kubectl get pvc -n <namespace>

# Проверь данные в БД
kubectl exec -it <postgres-pod> -n <namespace> -- psql -U app -d app -c "SELECT COUNT(*) FROM users;"
```

---

## Важно

1. `--existing-resource-policy=update` **НЕ восстанавливает данные PVC** - только метаданные
2. Для восстановления данных PVC - сначала удали существующий PVC
3. ArgoCD может пересоздать ресурсы быстрее чем Velero restore - отключай sync
4. CNPG operator автоматически создает пустой PVC - удаляй Cluster ресурс перед restore

---

## DR Plan: Restore ArgoCD Project

Восстановление всех приложений в ArgoCD project (data, applications, monitoring и т.д.)

### ArgoCD Projects:

| Project | Описание | Namespaces |
|---------|----------|------------|
| data | Databases (PostgreSQL, Redis) | example-api-*, example-ui-* |
| applications | Business apps | example-api-*, example-ui-* |
| monitoring | Prometheus, Grafana, Loki | monitoring |
| infrastructure | Operators, storage, secrets | longhorn-system, external-secrets, cnpg-system |

### Шаги:

```bash
# 1. Проверь доступные backups
velero backup get

# 2. Выбери backup
velero backup describe <backup-name> --details

# 3. Получи список apps в project
argocd app list -p data -o name
argocd app list -p applications -o name

# 4. Удали все apps в project (останавливает sync)
argocd app list -p data -o name | xargs argocd app delete -y --wait
argocd app list -p applications -o name | xargs argocd app delete -y --wait

# Или через kubectl (без argocd CLI):
kubectl get applications -n argocd -o json | \
  jq -r '.items[] | select(.spec.project=="data") | .metadata.name' | \
  xargs -I {} kubectl delete application {} -n argocd

# 5. Удали namespaces
kubectl delete namespace example-api-dev example-api-prd example-ui-dev example-ui-prd

# 6. Дождись удаления
kubectl get namespace | grep example

# 7. Restore
velero restore create project-restore \
  --from-backup <backup-name> \
  --include-namespaces example-api-dev,example-api-prd,example-ui-dev,example-ui-prd \
  --wait

# 8. Проверь restore
velero restore describe project-restore
kubectl get pods -A | grep example
kubectl get pvc -A | grep example

# 9. ArgoCD root app автоматически пересоздаст Applications
kubectl get applications -n argocd | grep example

# 10. Проверь данные
kubectl exec -it example-api-main-db-dev-cluster-1 -n example-api-dev \
  -- psql -U app -d app -c "SELECT COUNT(*) FROM users;"
```

---

## DR Plan: Restore Monitoring Project

```bash
# 1. Проверь backup
velero backup get
velero backup describe daily-critical-<timestamp> --details

# 2. Удали apps в project monitoring
argocd app list -p monitoring -o name | xargs argocd app delete -y --wait

# 3. Удали namespace
kubectl delete namespace monitoring

# 4. Restore
velero restore create monitoring-restore \
  --from-backup daily-critical-<timestamp> \
  --include-namespaces monitoring \
  --wait

# 5. Проверь
kubectl get pods -n monitoring
kubectl get pvc -n monitoring

# 6. ArgoCD пересоздаст apps
kubectl get applications -n argocd | grep -E "prometheus|grafana|loki"
```

---

## DR Plan: Restore Full Cluster (weekly-full)

Полное восстановление кластера из weekly backup.

### Что включает weekly-full backup:
- Все namespaces кроме: kube-system, kube-public, kube-node-lease, velero
- Все PVC данные (Prometheus, Grafana, PostgreSQL, Redis)
- Все secrets, configmaps, deployments

### Сценарий: Полная потеря кластера

```bash
# === НА НОВОМ КЛАСТЕРЕ ===

# 1. Установи Velero с тем же S3 storage
helm install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  --set configuration.backupStorageLocation[0].bucket=<bucket> \
  --set configuration.backupStorageLocation[0].config.region=<region> \
  --set configuration.backupStorageLocation[0].config.s3Url=<s3-url>

# 2. Дождись синхронизации с S3
velero backup-location get
velero backup get

# 3. Найди последний weekly-full backup
velero backup get --selector velero.io/schedule-name=weekly-full

# 4. Restore (весь кластер)
velero restore create full-cluster-restore \
  --from-backup weekly-full-<timestamp> \
  --wait

# 5. Проверь restore
velero restore describe full-cluster-restore --details
velero restore logs full-cluster-restore

# 6. Проверь все namespaces
kubectl get namespaces
kubectl get pods -A

# 7. Если ArgoCD восстановился - он досинхронизирует остальное
kubectl get applications -n argocd
```

### Сценарий: Частичная потеря (namespace corruption)

```bash
# 1. Определи какие namespaces повреждены
kubectl get pods -A | grep -E "Error|CrashLoop"

# 2. Удали поврежденные ArgoCD Applications
kubectl delete application <app-name> -n argocd

# 3. Удали поврежденные namespaces
kubectl delete namespace <namespace>

# 4. Selective restore
velero restore create partial-restore \
  --from-backup weekly-full-<timestamp> \
  --include-namespaces <namespace1>,<namespace2> \
  --wait

# 5. ArgoCD пересоздаст Applications автоматически
```

### Сценарий: Восстановление только данных (PVC)

```bash
# 1. Scale down workloads
kubectl scale deployment --all -n <namespace> --replicas=0
kubectl scale statefulset --all -n <namespace> --replicas=0

# 2. Удали CNPG clusters (они удалят PVC)
kubectl delete cluster --all -n <namespace>

# 3. Удали Redis PVC
kubectl delete pvc -l app.kubernetes.io/name=redis -n <namespace>

# 4. Restore только PVC
velero restore create data-restore \
  --from-backup weekly-full-<timestamp> \
  --include-namespaces <namespace> \
  --include-resources persistentvolumeclaims,persistentvolumes \
  --wait

# 5. Scale up (ArgoCD сделает это автоматически если selfHeal включен)
```

---

## Checklist после restore

- [ ] Все pods Running
- [ ] Все PVC Bound
- [ ] Данные в PostgreSQL восстановлены
- [ ] Данные в Redis восстановлены (если persistent)
- [ ] Grafana dashboards на месте
- [ ] Prometheus metrics восстановлены
- [ ] ArgoCD Applications synced
- [ ] Ingress работают
- [ ] External DNS записи обновились

---

## Ссылки

- [Velero Restore Reference](https://velero.io/docs/main/restore-reference/)
- [Stakater - Restore with GitOps](https://docs.stakater.com/saap/for-developers/how-to-guides/velero-restore-with-gitops.html)
