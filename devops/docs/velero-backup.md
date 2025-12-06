# Velero Backup & Restore

## Текущий статус: ОТКЛЮЧЁН

**Причина:** В GitOps системе с CNPG Velero избыточен:

| Компонент | Source of Truth | Velero нужен? |
|-----------|-----------------|---------------|
| K8s manifests | Git | ❌ |
| Secrets | Doppler → ExternalSecrets | ❌ |
| PostgreSQL | CNPG → S3 backup | ❌ |
| Redis | Кэш (эфемерный) | ❌ |

**Все schedules на паузе.** Velero оставлен для возможного DR в будущем.

```bash
# Проверить статус
velero schedule get  # PAUSED=true

# Возобновить если нужно
velero schedule unpause <schedule-name>
```

---

## Когда Velero нужен

1. **Миграция кластера** — перенос workloads между кластерами
2. **Stateful apps без своего backup** — если появятся приложения без встроенного backup
3. **Быстрый DR** — восстановить CRDs/состояние быстрее чем GitOps sync

## Установка

См. [phase11/02-velero-install.md](phase11/02-velero-install.md)

## Настройка Schedules

```yaml
# apps/templates/backup/velero.yaml - schedules section
schedules:
  daily-infrastructure:
    disabled: false  # true = отключён
    schedule: "0 3 * * *"
    template:
      ttl: 168h
      includeNamespaces:
        - argocd
        - cert-manager
      # Без FSB - только k8s objects
      snapshotVolumes: false
      defaultVolumesToFsBackup: false
```

### Рекомендуемые schedules для GitOps

| Schedule | Namespaces | FSB | Зачем |
|----------|------------|-----|-------|
| daily-infrastructure | argocd, cert-manager | ❌ | Быстрый DR |
| weekly-full | all (except kube-*) | ❌ | Полный snapshot состояния |

**FSB не нужен** — данные в Git/Doppler/CNPG S3.

## Backup

```bash
# Manual backup (без volumes)
velero backup create my-backup \
  --include-namespaces <ns> \
  --snapshot-volumes=false \
  --wait

# Список бэкапов
velero backup get
velero backup describe <backup> --details
```

## Restore

```bash
# Простой restore (k8s objects only)
velero restore create --from-backup <backup> --wait

# В конкретный namespace
velero restore create --from-backup <backup> --include-namespaces <ns> --wait

# С переименованием namespace
velero restore create --from-backup <backup> --namespace-mappings old:new --wait
```

### При restore в GitOps

```bash
# 1. Pause ArgoCD app
kubectl patch app <app> -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'

# 2. Restore
velero restore create --from-backup <backup> --include-namespaces <ns> --wait

# 3. Resume ArgoCD
kubectl patch app <app> -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true}}}}'
```

## Troubleshooting

```bash
# Velero logs
kubectl logs -n velero deploy/velero

# Backup/restore status
velero backup describe <backup> --details
velero restore describe <restore> --details
velero restore logs <restore>
```

## CLI Installation

```bash
# macOS
brew install velero

# Linux
wget https://github.com/vmware-tanzu/velero/releases/download/v1.17.1/velero-v1.17.1-linux-amd64.tar.gz
tar -xvf velero-v1.17.1-linux-amd64.tar.gz
sudo mv velero-v1.17.1-linux-amd64/velero /usr/local/bin/
```

## Quick Reference

| Action | Command |
|--------|---------|
| List schedules | `velero schedule get` |
| Pause schedule | `velero schedule pause <name>` |
| Unpause schedule | `velero schedule unpause <name>` |
| List backups | `velero backup get` |
| Manual backup | `velero backup create <name> --include-namespaces <ns>` |
| Restore | `velero restore create --from-backup <backup> --wait` |
| Delete backup | `velero backup delete <name>` |
