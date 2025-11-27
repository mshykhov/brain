# Tailscale Kubernetes Operator

**Docs:** https://tailscale.com/kb/1236/kubernetes-operator
**Установка:** GitOps (ArgoCD)

Даёт доступ к kubectl через Tailscale:
```bash
tailscale configure kubeconfig tailscale-operator
kubectl get nodes
```

## Prerequisites (до ArgoCD sync!)

### 1. ACL Policy

https://login.tailscale.com/admin/acls

```json
{
  "tagOwners": {
    "tag:k8s-operator": [],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "acls": [
    {"action": "accept", "src": ["autogroup:member"], "dst": ["tag:k8s-operator:443"]}
  ]
}
```

### 2. OAuth Client

https://login.tailscale.com/admin/settings/oauth
- Scopes: Devices (Write), Auth Keys (Write)
- Tag: `tag:k8s-operator`
- Сохрани Client ID и Secret

### 3. Kubernetes Secret

```bash
kubectl create namespace tailscale
kubectl create secret generic operator-oauth \
  --from-literal=client_id="YOUR_CLIENT_ID" \
  --from-literal=client_secret="YOUR_CLIENT_SECRET" \
  -n tailscale
```

### 4. RBAC

```bash
kubectl create clusterrolebinding tailscale-admin \
  --clusterrole=cluster-admin \
  --user="your-email@gmail.com"
```

## После ArgoCD sync

```bash
# Проверить
kubectl get pods -n tailscale

# Подключиться (с локальной машины)
tailscale configure kubeconfig tailscale-operator
kubectl get nodes
```

## Файлы в test-infrastructure

```
apps/templates/tailscale-operator.yaml  # Helm chart (Wave 4)
apps/templates/tailscale-config.yaml    # RBAC (Wave 5)
manifests/tailscale-config/
├── oauth-secret.example.yaml           # Template
└── rbac.yaml                           # RBAC manifests
```
