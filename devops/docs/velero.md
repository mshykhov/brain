# Velero Commands

Команды для backup/restore операций в Kubernetes.

## Установка CLI

```bash
brew install velero
```

Или:

```bash
VERSION=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | grep tag_name | cut -d '"' -f 4)
wget https://github.com/vmware-tanzu/velero/releases/download/${VERSION}/velero-${VERSION}-linux-amd64.tar.gz
tar -xvf velero-${VERSION}-linux-amd64.tar.gz
sudo mv velero-${VERSION}-linux-amd64/velero /usr/local/bin/
```

## Статус

```bash
velero version
velero backup-location get
velero schedule get
```

## Backup

```bash
velero backup create my-backup \
  --include-namespaces example-api-dev \
  --default-volumes-to-fs-backup \
  --wait
```

### С TTL

```bash
velero backup create my-backup \
  --include-namespaces monitoring \
  --ttl 168h \
  --wait
```

### От schedule

```bash
velero backup create --from-schedule daily-backup
```

## Restore

### Полный restore

```bash
velero restore create --from-backup my-backup --wait
```

### Только определенные ресурсы

```bash
velero restore create --from-backup my-backup \
  --include-resources configmaps,secrets \
  --wait
```

### В другой namespace

```bash
velero restore create --from-backup prd-backup \
  --namespace-mappings example-api-prd:example-api-staging
```

## Информация

```bash
velero backup get
velero backup describe my-backup --details
velero backup logs my-backup

velero restore get
velero restore describe my-restore
velero restore logs my-restore
```

## Удаление

```bash
velero backup delete my-backup
velero restore delete my-restore
```

## Troubleshooting

```bash
kubectl logs -n velero deployment/velero
kubectl logs -n velero -l name=node-agent
kubectl get backups -n velero
kubectl get restores -n velero
```
