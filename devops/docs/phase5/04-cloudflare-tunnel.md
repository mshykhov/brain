# Cloudflare Tunnel

Docs: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/

## Overview

Cloudflare Tunnel обеспечивает безопасный публичный доступ к сервисам без:
- Port forwarding на роутере
- Открытых портов на сервере
- Статического IP

**Бонусы:**
- Бесплатная DDoS защита
- WAF (Web Application Firewall)
- CDN кеширование
- Работает из любой сети

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                │
│                            ↓                                    │
│                    Cloudflare Edge                              │
│                    (DDoS, WAF, CDN)                             │
│                            ↓                                    │
│              ┌─────────────────────────┐                        │
│              │   Cloudflare Tunnel     │                        │
│              │   (outbound connection) │                        │
│              └─────────────────────────┘                        │
│                            ↓                                    │
│   ┌────────────────────────────────────────────────────────┐    │
│   │                    KUBERNETES                          │    │
│   │                                                        │    │
│   │   cloudflared pod ──→ traefik.traefik.svc:443         │    │
│   │                              ↓                         │    │
│   │                    IngressRoute / Services             │    │
│   └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Cloudflare Account + Domain

1. Создай бесплатный аккаунт: https://dash.cloudflare.com/sign-up
2. Добавь домен (можно купить дешёвый ~$10/год или перенести существующий)
3. Обнови NS записи у регистратора на Cloudflare

### 2. Create Tunnel in Zero Trust Dashboard

1. Открой: https://one.dash.cloudflare.com/
2. Networks → Tunnels → Create a tunnel
3. Выбери "Cloudflared" connector
4. Дай имя: `k8s-tunnel`
5. **СОХРАНИ ТОКЕН** - он показывается только один раз!
6. Пропусти шаг "Install connector" (мы деплоим через Helm)

### 3. Configure Public Hostname

В том же wizard или после создания:

1. Public Hostnames → Add a public hostname
2. Настрой routes:

| Subdomain | Domain | Path | Service |
|-----------|--------|------|---------|
| api | example.com | | http://traefik.traefik.svc:80 |
| api-dev | example.com | | http://traefik.traefik.svc:80 |

**Service URL:** `http://traefik.traefik.svc:80` - это внутренний Kubernetes service.

### 4. Add Token to Doppler

Добавь в Doppler → `example` project → `shared` config:

| Key | Value |
|-----|-------|
| `CF_TUNNEL_TOKEN` | eyJhIjoiNjk0ZDg5... (твой токен) |

## Files

| File | Purpose |
|------|---------|
| `helm-values/network/cloudflare-tunnel.yaml` | Helm values |
| `manifests/network/cloudflare-credentials/external-secret.yaml` | Token from Doppler |
| `apps/templates/network/cloudflare-credentials.yaml` | ArgoCD App (wave 15) |
| `apps/templates/network/cloudflare-tunnel.yaml` | ArgoCD App (wave 16) |

## Sync Waves

| Wave | Application |
|------|-------------|
| 15 | cloudflare-credentials (ExternalSecret) |
| 16 | cloudflare-tunnel (Helm chart) |

## Verification

```bash
# Check cloudflared pods
kubectl get pods -n cloudflare

# Check logs
kubectl logs -n cloudflare -l app.kubernetes.io/name=cloudflare-tunnel-remote

# Check tunnel status in Cloudflare Dashboard
# Networks → Tunnels → k8s-tunnel → Should show "HEALTHY"
```

## Testing

После деплоя:

```bash
# Test public access
curl https://api.example.com/health

# Should return your API response
```

## Updating Routes

Все routes настраиваются в **Cloudflare Zero Trust Dashboard**:
- Networks → Tunnels → k8s-tunnel → Public Hostnames

Изменения применяются мгновенно, без редеплоя.

## Comparison with Other Options

| Feature | Cloudflare Tunnel | Port Forwarding | Tailscale Funnel |
|---------|-------------------|-----------------|------------------|
| No router config | ✅ | ❌ | ✅ |
| Custom domain | ✅ | ✅ | ❌ (*.ts.net only) |
| DDoS protection | ✅ | ❌ | ❌ |
| WAF | ✅ | ❌ | ❌ |
| Production ready | ✅ | ✅ | ⚠️ beta |
| Free | ✅ | ✅ | ✅ |

## Troubleshooting

### Tunnel not connecting

1. Check token is correct in Doppler
2. Check ExternalSecret synced:
   ```bash
   kubectl get externalsecret -n cloudflare
   ```
3. Check cloudflared logs:
   ```bash
   kubectl logs -n cloudflare -l app.kubernetes.io/name=cloudflare-tunnel-remote
   ```

### 502 Bad Gateway

1. Check Traefik is running:
   ```bash
   kubectl get pods -n traefik
   ```
2. Verify service URL in Cloudflare Dashboard:
   - Should be `http://traefik.traefik.svc:80`
   - NOT `https://` (TLS terminates at Cloudflare edge)

### DNS not resolving

1. Check domain is active in Cloudflare
2. Verify CNAME record was created automatically
3. Wait for DNS propagation (up to 5 minutes)
