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
    argocd.argoproj.io/sync-wave: "10"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: infrastructure
  source:
    repoURL: https://helm.releases.hashicorp.com
    chart: vault
    targetRevision: "0.29.1"
    helm:
      valueFiles:
        - $values/helm-values/core/vault.yaml
  sources:
    - repoURL: https://helm.releases.hashicorp.com
      chart: vault
      targetRevision: "0.29.1"
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
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## 2. Helm Values

`infrastructure/helm-values/core/vault.yaml`:

```yaml
global:
  enabled: true

server:
  # HA mode with Raft storage
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      setNodeId: true
      config: |
        ui = true
        listener "tcp" {
          tls_disable = 1
          address = "[::]:8200"
          cluster_address = "[::]:8201"
        }
        storage "raft" {
          path = "/vault/data"
        }
        service_registration "kubernetes" {}

  # Persistent storage
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: longhorn

  # Resources
  resources:
    requests:
      memory: 256Mi
      cpu: 100m
    limits:
      memory: 512Mi
      cpu: 500m

  # Service
  service:
    type: ClusterIP

  # Ingress disabled - will use Tailscale
  ingress:
    enabled: false

# UI enabled
ui:
  enabled: true
  serviceType: ClusterIP

# Injector disabled (using external-secrets instead)
injector:
  enabled: false
```

## 3. Initialize Vault

После установки нужно инициализировать Vault:

```bash
# Get vault pod
VAULT_POD=$(kubectl get pod -n vault -l app.kubernetes.io/name=vault -o jsonpath='{.items[0].metadata.name}')

# Initialize (сохрани ключи в безопасном месте!)
kubectl exec -n vault $VAULT_POD -- vault operator init \
  -key-shares=5 \
  -key-threshold=3

# Output:
# Unseal Key 1: xxx
# Unseal Key 2: xxx
# Unseal Key 3: xxx
# Unseal Key 4: xxx
# Unseal Key 5: xxx
# Initial Root Token: hvs.xxx
```

## 4. Unseal Vault

```bash
# Unseal each replica (нужно 3 ключа из 5)
for pod in vault-0 vault-1 vault-2; do
  kubectl exec -n vault $pod -- vault operator unseal <key1>
  kubectl exec -n vault $pod -- vault operator unseal <key2>
  kubectl exec -n vault $pod -- vault operator unseal <key3>
done
```

## 5. Store Keys in Doppler

Сохрани в Doppler (project: `infrastructure`):

```
VAULT_UNSEAL_KEY_1=xxx
VAULT_UNSEAL_KEY_2=xxx
VAULT_UNSEAL_KEY_3=xxx
VAULT_UNSEAL_KEY_4=xxx
VAULT_UNSEAL_KEY_5=xxx
VAULT_ROOT_TOKEN=hvs.xxx
```

## 6. Auto-Unseal (Optional)

Для production рекомендуется настроить auto-unseal через:
- AWS KMS
- GCP Cloud KMS
- Azure Key Vault
- Transit secrets engine (другой Vault)

## 7. Verify Installation

```bash
# Check status
kubectl exec -n vault vault-0 -- vault status

# Login
kubectl exec -n vault vault-0 -- vault login <root_token>

# Check
kubectl exec -n vault vault-0 -- vault secrets list
```

## Next Steps

→ [02-pki-engine.md](02-pki-engine.md)
