# Tailscale Kubernetes Operator

**Docs:** https://tailscale.com/kb/1236/kubernetes-operator

Даёт доступ к kubectl через Tailscale:
```bash
tailscale configure kubeconfig tailscale-operator
kubectl get nodes
```

## Prerequisites

### 1. ACL Policy

https://login.tailscale.com/admin/acls → добавить:

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

https://login.tailscale.com/admin/settings/oauth → Generate:
- Scopes: Devices (Write), Auth Keys (Write)
- Tag: `tag:k8s-operator`
- Сохрани Client ID и Secret

### 3. Kubernetes Secret (вручную, до ArgoCD sync)

```bash
kubectl create namespace tailscale

kubectl create secret generic tailscale-operator-oauth \
  --from-literal=client_id="YOUR_CLIENT_ID" \
  --from-literal=client_secret="YOUR_CLIENT_SECRET" \
  -n tailscale
```

### 4. RBAC для своего пользователя

```bash
kubectl create clusterrolebinding tailscale-admin \
  --clusterrole=cluster-admin \
  --user="your-email@gmail.com"
```

## Установка через ArgoCD

После создания секрета — ArgoCD задеплоит Operator автоматически из `apps/templates/tailscale-operator.yaml`.

## Подключение

**Windows:** https://tailscale.com/download/windows

```bash
tailscale configure kubeconfig tailscale-operator
kubectl get nodes
```

## Проверка

```bash
kubectl get pods -n tailscale
# В Admin Console должен появиться tailscale-operator
```
