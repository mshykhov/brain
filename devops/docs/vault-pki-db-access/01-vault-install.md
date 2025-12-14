# Vault Installation

## 1. ArgoCD Application

`infrastructure/apps/templates/core/vault.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "5"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: infrastructure
  sources:
    - repoURL: https://helm.releases.hashicorp.com
      chart: vault
      targetRevision: "0.30.0"
      helm:
        valueFiles:
          - $values/helm-values/core/vault.yaml
    - repoURL: git@github.com:mshykhov/smhomelab-infrastructure.git
      targetRevision: master
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: vault
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    managedNamespaceMetadata:
      labels:
        tier: infrastructure
        team: platform
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
```

## 2. Helm Values

`infrastructure/helm-values/core/vault.yaml`:

```yaml
global:
  enabled: true
  tlsDisable: true  # TLS handled by Tailscale

server:
  # Standalone mode (single node)
  standalone:
    enabled: true
    config: |
      ui = true
      listener "tcp" {
        tls_disable = 1
        address = "[::]:8200"
        cluster_address = "[::]:8201"
      }
      storage "file" {
        path = "/vault/data"
      }

  ha:
    enabled: false

  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 500m

  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: longhorn

  auditStorage:
    enabled: true
    size: 5Gi
    storageClass: longhorn

ui:
  enabled: true
  serviceType: ClusterIP

csi:
  enabled: false

injector:
  enabled: false

serverTelemetry:
  serviceMonitor:
    enabled: true
    selectors:
      release: kube-prometheus-stack
```

## 3. Initialize Vault

После ArgoCD sync, подключаемся к поду:

```bash
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault operator init -key-shares=1 -key-threshold=1"
```

Output:

```
Unseal Key 1: xxx
Initial Root Token: hvs.xxx
```

## 4. Unseal Vault

```bash
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault operator unseal <unseal_key>"
```

## 5. Store Keys in Doppler

Сохраняем в Doppler project `shared`:

| Key | Value |
|-----|-------|
| `VAULT_UNSEAL_KEY` | Unseal key из init |
| `VAULT_ROOT_TOKEN` | Root token из init |

## 6. Verify Installation

```bash
# Check status
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault status"

# Login
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault login <root_token>"

# Check secrets engines
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault secrets list"
```

## Next Steps

→ [02-pki-engine.md](02-pki-engine.md)
