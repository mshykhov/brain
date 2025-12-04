# Cloudflare Tunnel - Full GitOps

## Overview

Полностью GitOps-managed Cloudflare Tunnel с автоматическим DNS через External-DNS.

**Components:**
- **cloudflared** - locally-managed tunnel with config.yaml
- **External-DNS** - auto-creates DNS records from Ingress annotations
- **protected-services** - centralized ingress configuration

**Official docs:**
- [Create locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-local-tunnel/)
- [Configuration file](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/local-management/configuration-file/)
- [Kubernetes example](https://github.com/cloudflare/argo-tunnel-examples/blob/master/named-tunnel-k8s/cloudflared.yaml)
- [External-DNS Cloudflare](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md)

## Architecture

```
Internet → Cloudflare Edge → cloudflared (tunnel) → NGINX Ingress → App Pods
                                                          ↑
                                              External-DNS creates
                                              CNAME: hostname → tunnel.cfargotunnel.com
```

## Setup

### Step 1: Install cloudflared

```bash
# Linux
curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared.deb

# macOS
brew install cloudflared
```

### Step 2: Create Tunnel

```bash
# Authenticate (opens browser)
cloudflared tunnel login

# Create tunnel (saves credentials to ~/.cloudflared/<UUID>.json)
cloudflared tunnel create k8s-tunnel

# Get tunnel UUID
cloudflared tunnel list
```

### Step 3: Create Cloudflare API Token

1. [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens) → API Tokens
2. Create Token → Custom token
3. Permissions:
   - Zone → Zone → Read
   - Zone → DNS → Edit
4. Zone Resources: All zones
5. Create Token → Copy

### Step 4: Add Secrets to Doppler

In Doppler Dashboard → `shared` config:

| Key | Value |
|-----|-------|
| `CF_TUNNEL_CREDENTIALS` | `cat ~/.cloudflared/<UUID>.json \| base64 -w0` |
| `CF_API_TOKEN` | API token from step 3 |

### Step 5: Update Tunnel UUID

Update `cloudflare-tunnel/values.yaml`:
```yaml
tunnel:
  uuid: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Step 6: Commit & Push

ArgoCD will sync automatically. External-DNS will create DNS records.

## Configuration

### protected-services/values.yaml

```yaml
# Service parameters:
#   enabled: bool       - enable/disable ingress
#   namespace: string   - target namespace
#   hostname: string    - public domain (enables External-DNS)
#   path: string        - ingress path (default: /)
#   oauth2: bool        - enable OAuth2-Proxy auth (default: true)
#   allowedGroups: []   - Auth0 groups for access control
#   backend.name: str   - service name
#   backend.port: int   - service port
#
# Routing:
#   - With hostname: public via Cloudflare Tunnel
#   - Without hostname: private via Tailscale

services:
  example-api-prd:
    enabled: true
    oauth2: false
    hostname: api.example.com
    namespace: example-api-prd
    backend:
      name: example-api-prd
      port: 8080
```

### cloudflare-tunnel/values.yaml

```yaml
tunnel:
  uuid: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

ingress:
  - hostname: api.example.com
    service: http://nginx-ingress-ingress-nginx-controller.nginx-ingress.svc.cluster.local:80
```

## Adding New Domain

1. Add to `protected-services/values.yaml`:
```yaml
services:
  new-service:
    enabled: true
    hostname: new.example.com
    namespace: new-service
    backend:
      name: new-service
      port: 8080
```

2. Add to `cloudflare-tunnel/values.yaml`:
```yaml
ingress:
  - hostname: new.example.com
    service: http://nginx-ingress-ingress-nginx-controller.nginx-ingress.svc.cluster.local:80
```

3. Commit → ArgoCD sync → External-DNS creates DNS → Done!

## How It Works

1. **Ingress** created with annotations:
   ```yaml
   external-dns.alpha.kubernetes.io/hostname: api.example.com
   external-dns.alpha.kubernetes.io/target: <tunnel-id>.cfargotunnel.com
   external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
   ```

2. **External-DNS** creates CNAME in Cloudflare:
   ```
   api.example.com → <tunnel-id>.cfargotunnel.com
   ```

3. **Cloudflare Edge** routes request to tunnel

4. **cloudflared** matches hostname in config.yaml → forwards to nginx ingress

5. **NGINX Ingress** routes by Host header to service

## Verification

```bash
# Check tunnel connected
kubectl logs -n cloudflare -l app=cloudflared | grep "Connection"

# Check External-DNS
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f

# Check DNS
dig api.example.com

# Test endpoint
curl https://api.example.com/health
```

## Troubleshooting

### Tunnel not connecting
```bash
kubectl exec -n cloudflare -it deployment/cloudflared -- ls -la /etc/cloudflared/creds/
kubectl get configmap -n cloudflare cloudflared-config -o yaml
```

### DNS not created
```bash
kubectl get ingress -A -o yaml | grep external-dns
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep example.com
```

## Doppler Secrets

| Key | Config | Description |
|-----|--------|-------------|
| `CF_TUNNEL_CREDENTIALS` | shared | Base64 credentials.json |
| `CF_API_TOKEN` | shared | Cloudflare API token (Zone:Read, DNS:Edit) |

## Migration from Remote-Managed

If migrating from TUNNEL_TOKEN:
1. Complete setup above
2. Verify new tunnel works
3. Delete old tunnel in Cloudflare Dashboard
4. Remove `CF_TUNNEL_TOKEN` from Doppler
