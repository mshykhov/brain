# Cloudflare Tunnel - Full GitOps

## Overview

Полностью GitOps-managed Cloudflare Tunnel с автоматическим DNS через External-DNS.

**Компоненты:**
- **cloudflared** - locally-managed tunnel с config.yaml
- **External-DNS** - автоматически создаёт DNS записи на основе Ingress annotations
- **protected-services** - централизованная конфигурация всех ingress

**Официальная документация:**
- [Create locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/)
- [External-DNS Cloudflare](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/cloudflare.md)
- [Kubernetes example](https://github.com/cloudflare/argo-tunnel-examples/blob/master/named-tunnel-k8s/cloudflared.yaml)

## Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                         Git Repository                                 │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │ protected-services/values.yaml                                   │  │
│  │   services:                                                      │  │
│  │     example-api-prd:                                            │  │
│  │       cloudflare: true                                          │  │
│  │       hostname: api.untrustedonline.org  ←── External-DNS reads │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌───────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                             │
│                                                                        │
│  ┌──────────────┐    watches    ┌──────────────┐    creates DNS       │
│  │   Ingress    │ ◄──────────── │ External-DNS │ ──────────────────►  │
│  │ (annotations)│               └──────────────┘      Cloudflare API  │
│  └──────────────┘                                                      │
│         │                                                              │
│         ▼                                                              │
│  ┌──────────────┐         ┌──────────────┐                            │
│  │    NGINX     │ ◄────── │  cloudflared │ ◄──── Cloudflare Edge      │
│  │   Ingress    │         │   (tunnel)   │                            │
│  └──────────────┘         └──────────────┘                            │
│         │                                                              │
│         ▼                                                              │
│  ┌──────────────┐                                                      │
│  │  App Pods    │                                                      │
│  └──────────────┘                                                      │
└───────────────────────────────────────────────────────────────────────┘
```

## Step 1: Create Locally-Managed Tunnel

### 1.1 Install cloudflared CLI (Linux)

```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install cloudflared
```

### 1.2 Authenticate

```bash
cloudflared tunnel login
```

### 1.3 Create Tunnel

```bash
cloudflared tunnel create k8s-prd-tunnel
```

Сохрани:
- **Tunnel UUID** - нужен для values
- **credentials.json** - нужен для Doppler

### 1.4 Get Tunnel UUID

```bash
cloudflared tunnel list
```

## Step 2: Add Secrets to Doppler

В Doppler Dashboard → `shared` config:

| Key | Value | Description |
|-----|-------|-------------|
| `CF_TUNNEL_CREDENTIALS` | base64 encoded credentials.json | `cat ~/.cloudflared/<UUID>.json \| base64 -w0` |
| `CF_API_TOKEN` | API token | Zone:Read, DNS:Edit permissions |

### Create Cloudflare API Token

1. Cloudflare Dashboard → My Profile → API Tokens
2. Create Token → Custom token
3. Permissions:
   - Zone: Zone: Read
   - Zone: DNS: Edit
4. Zone Resources: All zones
5. Create Token → Copy

## Step 3: Update ArgoCD Values

В ArgoCD Application для protected-services добавить tunnelId:

```yaml
# apps/templates/services/protected-services.yaml
spec:
  source:
    helm:
      valuesObject:
        cloudflare:
          tunnelId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

И для cloudflare-tunnel:

```yaml
# apps/templates/network/cloudflare-tunnel.yaml
spec:
  source:
    helm:
      valuesObject:
        tunnel:
          uuid: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## How It Works

1. **Ingress создаётся** с annotations:
   ```yaml
   annotations:
     external-dns.alpha.kubernetes.io/hostname: api.untrustedonline.org
     external-dns.alpha.kubernetes.io/target: <tunnel-id>.cfargotunnel.com
     external-dns.alpha.kubernetes.io/cloudflare-proxied: "true"
   ```

2. **External-DNS видит** Ingress и создаёт CNAME в Cloudflare:
   ```
   api.untrustedonline.org → <tunnel-id>.cfargotunnel.com
   ```

3. **Cloudflare Edge** получает запрос и отправляет в tunnel

4. **cloudflared** получает запрос и смотрит config.yaml:
   ```yaml
   ingress:
     - hostname: api.untrustedonline.org
       service: http://nginx-ingress...
   ```

5. **NGINX Ingress** роутит по Host header к сервису

## Adding New Domain

Просто добавь в `protected-services/values.yaml`:

```yaml
services:
  new-service-prd:
    enabled: true
    oauth2: false
    cloudflare: true
    hostname: new.untrustedonline.org  # External-DNS создаст DNS
    namespace: new-service-prd
    backend:
      name: new-service-prd
      port: 8080
```

И добавь в `cloudflare-tunnel/values.yaml`:

```yaml
ingress:
  - hostname: new.untrustedonline.org
    service: http://nginx-ingress-ingress-nginx-controller.nginx-ingress.svc.cluster.local:80
```

ArgoCD sync → External-DNS создаст DNS → Готово!

## Files Structure

```
example-infrastructure/
├── apps/templates/network/
│   ├── cloudflare-tunnel.yaml      # ArgoCD Application
│   └── external-dns.yaml           # ArgoCD Application
├── charts/
│   ├── cloudflare-tunnel/
│   │   ├── templates/
│   │   │   ├── configmap.yaml      # config.yaml с ingress rules
│   │   │   └── deployment.yaml     # cloudflared pods
│   │   └── values.yaml             # tunnel UUID, ingress rules
│   ├── credentials/templates/
│   │   └── cloudflare.yaml         # ExternalSecrets для tunnel + DNS
│   └── protected-services/
│       ├── templates/
│       │   └── ingresses.yaml      # Ingress с external-dns annotations
│       └── values.yaml             # Services config
└── helm-values/network/
    └── external-dns.yaml           # External-DNS helm values
```

## Doppler Secrets

| Key | Config | Description |
|-----|--------|-------------|
| `CF_TUNNEL_CREDENTIALS` | shared | Base64 credentials.json |
| `CF_API_TOKEN` | shared | Cloudflare API token |

## Verification

```bash
# Check External-DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns -f

# Check DNS record created
dig api.untrustedonline.org

# Check tunnel connected
kubectl logs -n cloudflare -l app=cloudflared | grep "Connection"

# Test endpoint
curl https://api.untrustedonline.org/actuator/health
```

## Troubleshooting

### DNS not created

```bash
# Check External-DNS sees the Ingress
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns | grep "api.untrustedonline"

# Check Ingress has correct annotations
kubectl get ingress -n example-api-prd example-api-prd -o yaml
```

### Tunnel not connecting

```bash
# Check credentials mounted
kubectl exec -n cloudflare -it deployment/cloudflared -- ls -la /etc/cloudflared/creds/

# Check config
kubectl get configmap -n cloudflare cloudflared-config -o yaml
```

## Migration Checklist

- [ ] Install cloudflared CLI
- [ ] Run `cloudflared tunnel login`
- [ ] Create tunnel: `cloudflared tunnel create k8s-prd-tunnel`
- [ ] Add `CF_TUNNEL_CREDENTIALS` to Doppler (base64 encoded)
- [ ] Create Cloudflare API token (Zone:Read, DNS:Edit)
- [ ] Add `CF_API_TOKEN` to Doppler
- [ ] Update ArgoCD valuesObject with tunnel UUID
- [ ] Commit and push
- [ ] Wait for ArgoCD sync
- [ ] Verify DNS created by External-DNS
- [ ] Verify tunnel connected
- [ ] Test endpoints
- [ ] Delete old remotely-managed tunnel from Dashboard
- [ ] Remove old `CF_TUNNEL_TOKEN` from Doppler
