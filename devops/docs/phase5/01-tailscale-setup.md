# Tailscale Kubernetes Operator

Docs: https://tailscale.com/kb/1236/kubernetes-operator

## Overview

Tailscale Operator provides:
- **Ingress** — expose services to tailnet (ArgoCD, Longhorn)
- **API Server Proxy** — kubectl access via Tailscale
- **Egress** — route pod traffic through Tailscale (not used here)

## Prerequisites

Complete [00-prerequisites.md](00-prerequisites.md) first!

## What Gets Deployed

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| Operator Deployment | `tailscale` | Main controller |
| ProxyGroup | `tailscale` | HA ingress proxies (ts-ingress-0, ts-ingress-1) |
| IngressClass `tailscale` | cluster-wide | For Tailscale Ingress resources |
| CRDs | cluster-wide | ProxyGroup, Connector, etc. |
| API Server Proxy | in-process | kubectl via Tailscale |

## Configuration

### Helm Values

File: `helm-values/network/tailscale-operator.yaml`

```yaml
operatorConfig:
  defaultTags:
    - "tag:k8s-operator"
  hostname: "tailscale-operator"
  logging: "info"

proxyConfig:
  defaultTags: "tag:k8s"

apiServerProxyConfig:
  mode: "true"
  allowImpersonation: "true"

oauth: {}  # Credentials from external secret

oauthSecretVolume:
  secret:
    secretName: tailscale-oauth
```

### ExternalSecret for OAuth

The operator needs OAuth credentials from Doppler.

File: `manifests/network/tailscale-credentials/external-secret.yaml`

Creates secret `tailscale-oauth` in `tailscale` namespace with:
- `TS_OAUTH_CLIENT_ID`
- `TS_OAUTH_CLIENT_SECRET`

## ProxyGroup (High Availability)

Docs: https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress#high-availability

ProxyGroup позволяет:
- Один набор прокси для всех Ingress (вместо отдельного StatefulSet на каждый)
- Избежать race conditions ("optimistic lock errors")
- HA — если один pod упадёт, второй продолжит работать

### Manifest

`charts/protected-services/templates/tailscale-proxygroup.yaml`:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: ProxyGroup
metadata:
  name: ingress-proxies
  namespace: tailscale
spec:
  type: ingress
  replicas: 2  # 1 для dev, 2 для prod
  hostnamePrefix: ts-ingress
  tags:
    - tag:k8s
```

### ACL autoApprovers

Для автоматического одобрения Tailscale Services добавь в ACL:

```json
"autoApprovers": {
  "services": {
    "tag:k8s": ["tag:k8s"]
  }
}
```

## Tailscale Services

**Где смотреть URL сервисов:**

1. **Tailscale Admin Console:** https://login.tailscale.com/admin/services
2. **kubectl:** `kubectl get ingress -n ingress-nginx` (колонка ADDRESS)

Статусы в консоли:
- **Connected** — хост активно рекламирует сервис
- **Offline** — никто не рекламирует
- **Pending approval** — ждёт одобрения (проверь autoApprovers)

## Verification

After sync:

```bash
# Check operator pod
kubectl get pods -n tailscale

# Check ProxyGroup status
kubectl get proxygroup -n tailscale

# Check operator logs
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator

# Check Tailscale Admin Console → Machines
# Look for "tailscale-operator" with tag:k8s-operator
# Look for "ts-ingress-0", "ts-ingress-1" (ProxyGroup pods)

# Check Tailscale Admin Console → Services
# All ingress URLs will be listed there
```

## Configure kubectl Access

After operator joins tailnet:

```bash
# Get operator hostname from Tailscale Admin Console
# Usually: tailscale-operator

# Configure kubeconfig
tailscale configure kubeconfig tailscale-operator

# Test
kubectl get nodes
```

## Troubleshooting

### Operator not joining tailnet

1. Check OAuth credentials:
   ```bash
   kubectl get secret -n tailscale operator-oauth -o yaml
   ```

2. Check operator logs:
   ```bash
   kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator
   ```

3. Verify Doppler secrets are correct

### kubectl access denied

1. Verify HTTPS is enabled in Tailscale
2. Check ACL grants include your user/group
3. Verify `apiServerProxyConfig.mode: "true"` in values

### Ingress not accessible

1. Check proxy pod:
   ```bash
   kubectl get pods -n tailscale
   ```

2. Check Tailscale Machines for the ingress proxy

3. Verify ACL allows access to `tag:k8s:*`
