# Phase 5 Prerequisites

Complete these steps BEFORE deploying Phase 5 components.

## 1. Tailscale ACL Configuration

Open: https://login.tailscale.com/admin/acls

Add to your policy file (merge with existing):

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
    },
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:k8s-operator:443"]
    }
  ],
  "grants": [
    {
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s-operator"],
      "app": {
        "tailscale.com/cap/kubernetes": [{
          "impersonate": {
            "groups": ["system:masters"]
          }
        }]
      }
    }
  ]
}
```

### ACL Explanation:

| Rule | Purpose |
|------|---------|
| `tag:k8s-operator` | Tag for the operator itself |
| `tag:k8s` | Tag for Ingress proxies (ArgoCD, Longhorn, etc.) |
| `dst: tag:k8s:*` | Allow access to all k8s-tagged services |
| `dst: tag:k8s-operator:443` | Allow kubectl via API Server Proxy |
| `grants` | Give admins full cluster access via kubectl |

## 2. Create OAuth Client

Open: https://login.tailscale.com/admin/settings/oauth

1. Click **"Generate OAuth client"**

2. Select scopes:
   - ✅ **Devices: Core** (Read & Write)
   - ✅ **Auth Keys** (Read & Write)
   - ✅ **Services** (Read & Write) — required for API Server Proxy

3. Add tag: `tag:k8s-operator`

4. Click **"Generate client"**

5. **SAVE IMMEDIATELY** — Client Secret shown only once!
   - Client ID: `tskey-client-xxx`
   - Client Secret: `tskey-client-xxx-yyy`

## 3. Enable HTTPS for Tailnet

Required for API Server Proxy (kubectl access).

Open: https://login.tailscale.com/admin/dns

1. Scroll to **"HTTPS Certificates"**
2. Click **"Enable HTTPS"**
3. Confirm

This allows Tailscale to provision TLS certificates for your devices.

## 4. Add Secrets to Doppler

Open your Doppler project: `example` → config: `shared`

Add these secrets:

| Key | Value | Description |
|-----|-------|-------------|
| `TS_OAUTH_CLIENT_ID` | `tskey-client-xxx` | OAuth Client ID |
| `TS_OAUTH_CLIENT_SECRET` | `tskey-client-xxx-yyy` | OAuth Client Secret |

## 5. Verify Doppler Secrets

After adding, verify in Doppler UI that both secrets are present in `shared` config.

These will be synced to Kubernetes via External Secrets Operator (ClusterSecretStore `doppler-shared`).

## Checklist

- [ ] ACL policy updated with k8s tags
- [ ] ACL grants configured for kubectl access
- [ ] OAuth client created with correct scopes
- [ ] OAuth client tagged with `tag:k8s-operator`
- [ ] Client ID and Secret saved
- [ ] HTTPS enabled for tailnet
- [ ] Secrets added to Doppler `shared` config

## Next Steps

After completing prerequisites:
1. Commit and push `example-infrastructure` changes
2. ArgoCD will deploy Tailscale Operator
3. Operator joins tailnet automatically
4. Configure kubectl: `tailscale configure kubeconfig <operator-hostname>`
