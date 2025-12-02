# Phase 1: Longhorn

**Version:** 1.10.1
**Docs:** https://longhorn.io/docs/1.10.1/
**Установка:** GitOps (ArgoCD)

## Зачем

Distributed block storage для Kubernetes. Даёт PersistentVolumes на bare-metal с репликацией данных.

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│                    Longhorn System                       │
├─────────────────────────────────────────────────────────┤
│  Manager (DaemonSet)     │  Handles volume operations   │
│  UI (Deployment)         │  Web interface               │
│  CSI Driver              │  Kubernetes integration      │
│  Webhooks                │  Validation/Conversion       │
│  Instance Manager        │  Per-node engine management  │
└─────────────────────────────────────────────────────────┘
```

## Файлы

```
example-infrastructure/
├── apps/templates/core/longhorn.yaml     # ArgoCD Application
└── helm-values/core/longhorn.yaml        # Helm values
```

## Application (Multi-Source)

`apps/templates/core/longhorn.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: longhorn
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  sources:
    - repoURL: https://charts.longhorn.io
      chart: longhorn
      targetRevision: "1.10.1"
      helm:
        valueFiles:
          - $values/helm-values/core/longhorn.yaml
        valuesObject:
          preUpgradeChecker:
            jobEnabled: false  # Required for ArgoCD!
    - repoURL: {{ .Values.spec.source.repoURL }}
      targetRevision: {{ .Values.spec.source.targetRevision }}
      ref: values
  destination:
    namespace: longhorn-system
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
      - SkipDryRunOnMissingResource=true
```

## Helm Values (Single-Node Optimized)

`helm-values/core/longhorn.yaml`:

```yaml
# Reduce replicas for single-node (default is 2)
longhornUI:
  replicas: 1

longhornConversionWebhook:
  replicas: 1

longhornAdmissionWebhook:
  replicas: 1

longhornRecoveryBackend:
  replicas: 1

# Data replication (2 copies even on single-node)
persistence:
  defaultClassReplicaCount: 2  # Official default: 3

# CSI components (single replica for single-node)
csi:
  attacherReplicaCount: 1
  provisionerReplicaCount: 1
  resizerReplicaCount: 1
  snapshotterReplicaCount: 1

# CPU guarantees (% of node CPU)
defaultSettings:
  guaranteedEngineManagerCPU: 5
  guaranteedReplicaManagerCPU: 5
  concurrentReplicaRebuildPerNodeLimit: 2
  concurrentVolumeBackupRestorePerNodeLimit: 2
```

### Single-Node vs Multi-Node

| Setting | Single-Node | Multi-Node (HA) |
|---------|-------------|-----------------|
| `longhornUI.replicas` | 1 | 2 |
| `webhooks.replicas` | 1 | 2 |
| `defaultClassReplicaCount` | 2 | 3 |
| `csi.*ReplicaCount` | 1 | 2-3 |

## Key Settings Explained

### preUpgradeChecker.jobEnabled: false

**Required for ArgoCD!** Without this, ArgoCD hangs waiting for pre-upgrade Job.

### defaultClassReplicaCount

Number of data replicas per volume:
- `1` — No redundancy (data loss on disk failure)
- `2` — One copy survives disk failure
- `3` — Two copies survive (recommended for production)

### guaranteedEngineManagerCPU / guaranteedReplicaManagerCPU

Percentage of node CPU reserved for Longhorn instance managers. Value `5` = 5% CPU guaranteed.

## Sync Wave

- **Wave 3:** Early in deployment (storage needed for other apps)

## Verification

```bash
# All pods running
kubectl get pods -n longhorn-system

# StorageClass created (should be default)
kubectl get storageclass

# Longhorn nodes registered
kubectl get nodes.longhorn.io -n longhorn-system

# Test PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
kubectl delete pvc test-pvc
```

## UI Access

Via Tailscale (Phase 5):
```
https://longhorn.<tailnet>.ts.net
```

Or port-forward:
```bash
kubectl port-forward svc/longhorn-frontend -n longhorn-system 9000:80
# http://localhost:9000
```

## Requirements

- Kubernetes >= 1.25
- `open-iscsi` on nodes (installed by phase0-setup.sh)
- Disk space for volumes

## Troubleshooting

### Pods stuck in ContainerCreating

```bash
# Check if open-iscsi is installed
sudo systemctl status iscsid

# If not:
sudo apt install open-iscsi
sudo systemctl enable --now iscsid
```

### Volume stuck in Attaching

```bash
# Check instance manager logs
kubectl logs -n longhorn-system -l longhorn.io/component=instance-manager
```

### ArgoCD sync hangs

Ensure `preUpgradeChecker.jobEnabled: false` in values.
