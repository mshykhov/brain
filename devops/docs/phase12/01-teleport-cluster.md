# Teleport Cluster Installation

## 1. Add Helm Repository

```bash
helm repo add teleport https://charts.releases.teleport.dev
helm repo update
```

## 2. Create Namespace

```bash
kubectl create namespace teleport
kubectl label namespace teleport 'pod-security.kubernetes.io/enforce=baseline'
```

## 3. DNS Setup

Создать DNS record в Cloudflare:
- `teleport.gaynance.com` → Tailscale IP или LoadBalancer

Или использовать Tailscale для internal-only доступа:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: teleport-tailscale
  namespace: teleport
  annotations:
    tailscale.com/expose: "true"
    tailscale.com/hostname: "teleport"
spec:
  selector:
    app: teleport-cluster
  ports:
    - port: 443
      targetPort: 3080
```

## 4. Create Values File

`infrastructure/charts/teleport-cluster/values.yaml`:

```yaml
clusterName: teleport.gaynance.com  # или teleport.trout-paradise.ts.net
proxyListenerMode: multiplex

# TLS - Let's Encrypt
acme: true
acmeEmail: your-email@example.com

# Resources
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Persistence
persistence:
  enabled: true
  storageClassName: longhorn
  size: 10Gi

# High Availability (optional for prod)
highAvailability:
  replicaCount: 1  # increase for prod
  certManager:
    enabled: false

# Auth settings
auth:
  teleportConfig:
    auth_service:
      authentication:
        type: oidc
        connector_name: auth0
        webauthn:
          rp_id: teleport.gaynance.com

# Proxy settings
proxy:
  teleportConfig:
    proxy_service:
      https_keypairs: []
```

## 5. Install via ArgoCD

`infrastructure/apps/templates/infrastructure/teleport.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: teleport-cluster
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://charts.releases.teleport.dev
    chart: teleport-cluster
    targetRevision: 18.5.1
    helm:
      valuesObject:
        clusterName: teleport.trout-paradise.ts.net
        proxyListenerMode: multiplex
        acme: true
        acmeEmail: your-email@example.com
        persistence:
          enabled: true
          storageClassName: longhorn
          size: 10Gi
  destination:
    server: https://kubernetes.default.svc
    namespace: teleport
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 6. Verify Installation

```bash
kubectl get pods -n teleport
kubectl get svc -n teleport

# Check logs
kubectl logs -n teleport -l app=teleport-cluster -f
```

## 7. Create Initial Admin User

```bash
# Get auth pod
AUTH_POD=$(kubectl get pod -n teleport -l app=teleport-cluster -o jsonpath='{.items[0].metadata.name}')

# Create admin user (temporary, before SSO)
kubectl exec -n teleport -it $AUTH_POD -- tctl users add admin --roles=editor,access,auditor

# Follow the link to set password
```

## 8. Install tsh Client

```bash
# macOS
brew install teleport

# Windows (via scoop)
scoop bucket add extras
scoop install teleport

# Or download from https://goteleport.com/download/
```

## 9. Test Connection

```bash
tsh login --proxy=teleport.trout-paradise.ts.net --user=admin
tsh status
```

## Next Steps

→ [02-auth0-oidc.md](02-auth0-oidc.md)
