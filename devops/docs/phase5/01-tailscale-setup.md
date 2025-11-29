# Tailscale Kubernetes Operator Setup

Docs: https://tailscale.com/kb/1236/kubernetes-operator

## 1. ACL Policy Configuration

В Tailscale Admin Console → Access Controls (https://login.tailscale.com/admin/acls):

```json
{
  "tagOwners": {
    "tag:k8s-operator": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

## 2. OAuth Client

1. Settings → Trust credentials (https://login.tailscale.com/admin/settings/trust-credentials)
2. Create OAuth Client:
   - Scopes: `Devices Core`, `Auth Keys`, `Services` (Write)
   - Tag: `tag:k8s-operator`
3. Save Client ID и Client Secret

## 3. Doppler Secrets

Add to Doppler (project: `example`, config: `shared`):

| Key | Value |
|-----|-------|
| TS_OAUTH_CLIENT_ID | OAuth Client ID |
| TS_OAUTH_CLIENT_SECRET | OAuth Client Secret |

## 4. Sync & Verify

```bash
# Check operator joined tailnet
kubectl get pods -n tailscale

# Check Tailscale Admin Console → Machines
# Look for "tailscale-operator" with tag:k8s-operator
```

## 5. Access Admin UIs

After sync, available via Tailscale:
- https://argocd (ArgoCD)
- https://longhorn (Longhorn)
- https://traefik (Traefik Dashboard)
