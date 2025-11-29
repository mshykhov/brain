# Phase 5 Prerequisites

Complete these steps BEFORE deploying Phase 5 components.

Docs:
- https://tailscale.com/kb/1236/kubernetes-operator
- https://tailscale.com/kb/1458/grant-samples#allow-access-to-the-kubernetes-operator-with-privileges

## 1. Tailscale ACL Configuration

Open: https://login.tailscale.com/admin/acls

**IMPORTANT:** Keep existing `acls` section for device-to-device access! Only add/merge these sections:

```json
{
  "tagOwners": {
    "tag:k8s-operator": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["*:*"]
    }
  ],
  "grants": [
    {
      "src": ["autogroup:admin"],
      "dst": ["tag:k8s-operator"],
      "ip": ["*:*"],
      "app": {
        "tailscale.com/cap/kubernetes": [{
          "impersonate": {
            "groups": ["system:masters"]
          }
        }]
      }
    },
    {
      "src": ["autogroup:member"],
      "dst": ["tag:k8s"],
      "ip": ["*:443"]
    }
  ],
  "ssh": [
    {
      "action": "check",
      "src": ["autogroup:member"],
      "dst": ["autogroup:self"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

**WARNING:** Without `acls` section you will lose SSH access to your servers!

### Configuration Explained:

#### tagOwners
| Tag | Owners | Purpose |
|-----|--------|---------|
| `tag:k8s-operator` | `autogroup:admin` | Only admins can tag the operator |
| `tag:k8s` | `tag:k8s-operator` | Operator can assign tag:k8s to Ingress proxies |

#### grants[0] — Admin kubectl access
| Field | Value | Purpose |
|-------|-------|---------|
| `src` | `autogroup:admin` | Tailnet admins |
| `dst` | `tag:k8s-operator` | The operator device |
| `ip` | `*:*` | Full network access to operator |
| `app.tailscale.com/cap/kubernetes` | `system:masters` | Full cluster-admin in Kubernetes |

#### grants[1] — Member access to services
| Field | Value | Purpose |
|-------|-------|---------|
| `src` | `autogroup:member` | All tailnet members |
| `dst` | `tag:k8s` | All k8s Ingress proxies (ArgoCD, Longhorn, etc.) |
| `ip` | `*:443` | HTTPS only |

### Extending Access

**Add read-only kubectl for developers:**
```json
{
  "src": ["group:developers"],
  "dst": ["tag:k8s-operator"],
  "ip": ["*:*"],
  "app": {
    "tailscale.com/cap/kubernetes": [{
      "impersonate": {
        "groups": ["tailnet-readers"]
      }
    }]
  }
}
```

Then create ClusterRoleBinding in Kubernetes:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tailnet-readers
subjects:
  - kind: Group
    name: tailnet-readers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: view  # built-in read-only role
  apiGroup: rbac.authorization.k8s.io
```

**Restrict specific user to namespace:**
```json
{
  "src": ["user@example.com"],
  "dst": ["tag:k8s-operator"],
  "ip": ["*:*"],
  "app": {
    "tailscale.com/cap/kubernetes": [{
      "impersonate": {
        "groups": ["dev-team"]
      }
    }]
  }
}
```

## 2. Create OAuth Client

Open: https://login.tailscale.com/admin/settings/oauth

1. Click **"Generate OAuth client"**

2. Select scopes (Write includes Read):
   - ✅ **Devices: Core** — Write
   - ✅ **Auth Keys** — Write
   - ✅ **Services** — Write (required for API Server Proxy)

3. Add tag: `tag:k8s-operator`

4. Click **"Generate client"**

5. **SAVE IMMEDIATELY** — Client Secret shown only once!
   - Client ID: looks like `tskey-client-kXXXXX-XXXXX`
   - Client Secret: case-sensitive!

6. Click **"Done"**

## 3. Enable HTTPS for Tailnet

Required for API Server Proxy (kubectl access).

Open: https://login.tailscale.com/admin/dns

1. Scroll to **"HTTPS Certificates"**
2. Click **"Enable HTTPS"**
3. Confirm

## 4. Add Secrets to Doppler

Open Doppler project: `example` → config: `shared`

| Key | Value |
|-----|-------|
| `TS_OAUTH_CLIENT_ID` | Your OAuth Client ID |
| `TS_OAUTH_CLIENT_SECRET` | Your OAuth Client Secret |

## Checklist

- [ ] ACL policy with tagOwners configured
- [ ] Grant for admin kubectl access (system:masters)
- [ ] Grant for member access to k8s services (port 443)
- [ ] OAuth client created with correct scopes
- [ ] OAuth client tagged with `tag:k8s-operator`
- [ ] Client ID and Secret saved
- [ ] HTTPS enabled for tailnet
- [ ] Secrets added to Doppler `shared` config

## After Operator Deploys

### Configure kubectl

```bash
# Get operator hostname from Tailscale Machines page
# Default: tailscale-operator

tailscale configure kubeconfig tailscale-operator
kubectl get nodes
```

### Verify in Tailscale Admin

Check https://login.tailscale.com/admin/machines for:
- `tailscale-operator` with `tag:k8s-operator`
- Ingress proxies (argocd, longhorn) with `tag:k8s`
