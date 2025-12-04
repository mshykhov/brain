# Uptime Kuma - Status Page & Monitoring

## Overview

Self-hosted monitoring tool for tracking uptime of services, APIs, and websites.

**Features:**
- HTTP(s), TCP, DNS, Docker, Steam monitoring
- Notifications (Telegram, Discord, Slack, etc.)
- Status pages
- Multi-language support

**Official docs:**
- [Uptime Kuma](https://github.com/louislam/uptime-kuma)
- [Helm Chart](https://github.com/dirsigler/uptime-kuma-helm)

## Architecture

```
Internet → Cloudflare → cloudflared → nginx-ingress → oauth2-proxy → uptime-kuma
                                                            ↓
                                                     Auth0 (infra-admins)
```

## Access

| URL | Auth | Purpose |
|-----|------|---------|
| `status.untrustedonline.org` | Auth0 (infra-admins) | Dashboard & config |

## Configuration

### ArgoCD Application

```yaml
# apps/templates/monitoring/uptime-kuma.yaml
sources:
  - repoURL: https://dirsigler.github.io/uptime-kuma-helm
    chart: uptime-kuma
    targetRevision: "2.24.0"
```

### Helm Values

```yaml
# helm-values/monitoring/uptime-kuma.yaml
volume:
  size: 2Gi
  storageClassName: longhorn

serviceMonitor:
  enabled: true
```

### Protected Services

```yaml
# charts/protected-services/values.yaml
uptime-kuma:
  enabled: true
  hostname: status.untrustedonline.org
  namespace: monitoring
  websocket: true  # Required for real-time updates
  allowedGroups:
    - infra-admins
  backend:
    name: uptime-kuma
    port: 3001
```

WebSocket support adds nginx annotations per [official docs](https://kubernetes.github.io/ingress-nginx/user-guide/miscellaneous/#websockets):
```yaml
nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
```

## Initial Setup

After deployment:

1. Open `https://status.untrustedonline.org`
2. Create admin account (first user becomes admin)
3. Configure monitors for your services

### Recommended Monitors

| Name | Type | URL/Host | Interval |
|------|------|----------|----------|
| API PRD | HTTP | `https://api.untrustedonline.org/health` | 60s |
| UI PRD | HTTP | `https://untrustedonline.org` | 60s |
| ArgoCD | HTTP | `http://argocd-server.argocd.svc:80` | 60s |
| Grafana | HTTP | `http://kube-prometheus-stack-grafana.monitoring.svc:80` | 60s |

## Telegram Notifications

1. Settings → Notifications → Add
2. Type: Telegram
3. Bot Token: from `@BotFather`
4. Chat ID: your group/channel ID
5. Test & Save

## Verification

```bash
# Pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=uptime-kuma

# Logs
kubectl logs -n monitoring -l app.kubernetes.io/name=uptime-kuma

# Service
kubectl get svc -n monitoring uptime-kuma
```

## Troubleshooting

### Pod CrashLoopBackOff

Check if PVC is bound:
```bash
kubectl get pvc -n monitoring
```

### WebSocket errors

Uptime Kuma requires WebSocket support. The protected-services ingress includes necessary nginx annotations for WebSocket proxying.

### Cannot access after Auth0 login

Verify user is in `infra-admins` group in Auth0.
