# Velero Installation

## Prerequisites

1. R2 bucket created (`velero-backups`)
2. S3 credentials in Doppler:
   - `S3_ACCESS_KEY_ID`
   - `S3_SECRET_ACCESS_KEY`
3. Global S3 config in `apps/values.yaml`

## Configuration Files

### ArgoCD Application

```yaml
# apps/templates/backup/velero.yaml
sources:
  - repoURL: https://vmware-tanzu.github.io/helm-charts
    chart: velero
    targetRevision: "11.2.0"
    helm:
      valueFiles:
        - $values/helm-values/backup/velero.yaml
      valuesObject:
        configuration:
          backupStorageLocation:
            - name: default
              provider: velero.io/aws
              bucket: {{ .Values.global.s3.buckets.velero }}
              config:
                region: {{ .Values.global.s3.region }}
                s3Url: {{ .Values.global.s3.endpoint }}
```

### External Secret

```yaml
# charts/credentials/templates/velero.yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: velero-s3-credentials
  namespace: velero
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: velero-s3-credentials
    template:
      data:
        cloud: |
          [default]
          aws_access_key_id={{ .accessKeyId }}
          aws_secret_access_key={{ .secretAccessKey }}
  data:
    - secretKey: accessKeyId
      remoteRef:
        key: S3_ACCESS_KEY_ID
    - secretKey: secretAccessKey
      remoteRef:
        key: S3_SECRET_ACCESS_KEY
```

## Verification

```bash
# Check Velero pod
kubectl get pods -n velero

# Check backup location
velero backup-location get

# Check credentials
kubectl get secret -n velero velero-s3-credentials
```

## Version Compatibility

| Component | Version |
|-----------|---------|
| Velero | v1.17.1 |
| Helm Chart | 11.2.0 |
| AWS Plugin | v1.13.1 |

Source: https://github.com/vmware-tanzu/velero-plugin-for-aws#compatibility

## CLI Installation

```bash
# macOS
brew install velero

# Linux (amd64)
wget https://github.com/vmware-tanzu/velero/releases/download/v1.17.1/velero-v1.17.1-linux-amd64.tar.gz
tar -xvf velero-v1.17.1-linux-amd64.tar.gz
sudo mv velero-v1.17.1-linux-amd64/velero /usr/local/bin/
velero version

# Windows (via Chocolatey)
choco install velero
```
