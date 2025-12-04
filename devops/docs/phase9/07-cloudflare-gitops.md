# Cloudflare Tunnel - Full GitOps

## Overview

Полностью GitOps-managed Cloudflare Tunnel с автоматическим DNS через External-DNS.

**Components:**
- **cloudflared** - locally-managed tunnel with catch-all rule
- **External-DNS** - auto-creates DNS records from Ingress annotations
- **protected-services** - single source of truth for all services

**Official docs:**
- [Create locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/)
- [Configuration file](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/local-management/configuration-file/)
- [External-DNS Cloudflare](https://kubernetes-sigs.github.io/external-dns/v0.14.0/tutorials/cloudflare/)

## Architecture

```
Internet → Cloudflare Edge → cloudflared → NGINX Ingress → App Pods
                                  ↓               ↑
                           catch-all rule    Host header routing
                                  ↓
                        External-DNS creates CNAME:
                        hostname → tunnelId.cfargotunnel.com
```

## Setup

### Step 1: Install cloudflared

```bash
# Linux
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o cloudflared.deb && sudo dpkg -i cloudflared.deb

# macOS
brew install cloudflared
```

### Step 2: Create Tunnel

```bash
cloudflared tunnel login
cloudflared tunnel create k8s-tunnel
cloudflared tunnel list
cat ~/.cloudflared/<UUID>.json | base64 -w0
```

### Step 3: Create Cloudflare API Token

1. [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) → API Tokens
2. Create Token → "Edit zone DNS" template
3. Zone Resources: All zones
4. Create Token → Copy

### Step 4: Add Secrets to Doppler

| Key | Value |
|-----|-------|
| `CF_TUNNEL_CREDENTIALS` | base64 output from step 2 |
| `CF_API_TOKEN` | API token from step 3 |

### Step 5: Update Tunnel UUID

In `apps/values.yaml`:
```yaml
global:
  cloudflare:
    tunnelId: "<UUID>"
```

### Step 6: Commit & Push

ArgoCD syncs → External-DNS creates DNS records automatically.

## Adding New Public Service

**Only ONE file** - `charts/protected-services/values.yaml`:

```yaml
services:
  my-service:
    enabled: true
    hostname: my.example.com    # ← triggers External-DNS
    namespace: my-namespace
    backend: { name: my-service, port: 8080 }
```

**What happens automatically:**
1. Ingress created with External-DNS annotations
2. External-DNS creates CNAME: `my.example.com` → `tunnelId.cfargotunnel.com`
3. cloudflared routes ALL traffic to nginx-ingress (catch-all)
4. nginx-ingress routes by Host header

No changes needed in cloudflare-tunnel!

## How It Works

1. **Ingress** created with annotations:
   ```yaml
   external-dns.alpha.kubernetes.io/hostname: api.example.com
   external-dns.alpha.kubernetes.io/target: <tunnelId>.cfargotunnel.com
   external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
   ```

2. **External-DNS** creates CNAME: `api.example.com` → `<tunnelId>.cfargotunnel.com`

3. **Cloudflare Edge** routes to tunnel

4. **cloudflared** forwards ALL traffic to nginx-ingress (catch-all rule)

5. **NGINX Ingress** routes by Host header to service

## Verification

```bash
# Tunnel status
kubectl logs -n cloudflare -l app=cloudflared | grep "Connection"

# External-DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns

# Check DNS
dig api.example.com

# Test
curl https://api.example.com/health
```

## Troubleshooting

```bash
# Tunnel credentials
kubectl get secret -n cloudflare tunnel-credentials -o yaml

# Tunnel config
kubectl get configmap -n cloudflare cloudflared-config -o yaml

# External-DNS
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep -i error
```

## External-DNS Configuration

```yaml
# helm-values/network/external-dns.yaml
provider:
  name: cloudflare

env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: token

extraArgs:
  - --cloudflare-proxied
  - --cloudflare-dns-records-per-page=5000
  - --txt-prefix=extdns-      # Ownership tracking prefix

domainFilters:
  - untrustedonline.org       # Only manage this domain

policy: sync
txtOwnerId: external-dns
logLevel: debug
```

### Key Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `domainFilters` | `[untrustedonline.org]` | Limit to specific domain |
| `txt-prefix` | `extdns-` | TXT ownership records prefix |
| `txtOwnerId` | `external-dns` | Cluster identifier |
| `policy` | `sync` | Full sync (create/update/delete) |

## Ownership & Migration

External-DNS uses TXT records for ownership tracking:
- Each CNAME gets a TXT record: `extdns-<hostname>`
- Contains owner ID to prevent conflicts

**Problem:** Manually created DNS records have no owner → External-DNS skips them.

**Solution:** Delete manual records in Cloudflare Dashboard, let External-DNS recreate.

**Prevention:**
1. Never create DNS records manually for domains managed by External-DNS
2. Use `--txt-prefix` to avoid TXT/CNAME conflicts
3. Use unique `txtOwnerId` per cluster

## ExternalSecret Template (Helm Escaping)

When using ExternalSecret templates in Helm charts, escape Go templates:

```yaml
# charts/credentials/templates/cloudflare.yaml
template:
  data:
    credentials.json: "{{ `{{ .credentials | b64dec }}` }}"
```

- `b64dec` - ESO function to decode base64
- Backticks escape from Helm rendering

## Doppler Secrets

| Key | Description |
|-----|-------------|
| `CF_TUNNEL_CREDENTIALS` | Base64 credentials.json |
| `CF_API_TOKEN` | Cloudflare API token (DNS:Edit, All zones) |
