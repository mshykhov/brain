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

## Verification

After sync:

```bash
# Check operator pod
kubectl get pods -n tailscale

# Check operator logs
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator

# Check Tailscale Admin Console → Machines
# Look for "tailscale-operator" with tag:k8s-operator
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
