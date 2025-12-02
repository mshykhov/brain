# Phase 6: Cloudflare Setup

## Overview

Public access для production сервисов через Cloudflare Tunnel.

**Архитектура:**
```
Internet → Cloudflare Edge (DDoS, WAF, TLS) → Tunnel → K8s Services
```

**Что expose публично:**
- `api.yourdomain.com` → example-api.prd:8080
- `app.yourdomain.com` → example-ui.prd:80 (будущее)

**DEV остаётся private** через Tailscale (Phase 5).

## 1. Создание Cloudflare Account

1. Зайти на [cloudflare.com](https://cloudflare.com)
2. Sign Up (Free план)
3. Подтвердить email

## 2. Покупка домена

**Cloudflare Registrar** - домены по себестоимости (без markup):
- `.com` ~$9.77/год
- `.dev` ~$12/год
- `.io` ~$33/год

### Шаги:
1. Dashboard → Domain Registration → Register Domains
2. Поиск и выбор домена
3. Оплата (принимает карты)
4. DNS автоматически настроен на Cloudflare

> **Альтернатива:** Если домен уже есть у другого регистратора - добавить сайт в Cloudflare и сменить nameservers.

## 3. Создание Tunnel

### Zero Trust Dashboard

1. Dashboard → Zero Trust → Networks → Tunnels
2. Create a tunnel
3. Выбрать **Cloudflared** connector
4. Имя: `k8s-prd-tunnel`
5. **Скопировать TUNNEL_TOKEN** (нужен для Doppler)

### Public Hostnames (настраиваются после деплоя)

После запуска cloudflared в кластере, добавить routes:

| Hostname | Service | Path |
|----------|---------|------|
| api.yourdomain.com | http://example-api.prd:8080 | * |
| app.yourdomain.com | http://example-ui.prd:80 | * |

## 4. Doppler Secrets

Добавить в `shared` config:

| Key | Value | Source |
|-----|-------|--------|
| `CF_TUNNEL_TOKEN` | eyJ... | Zero Trust → Tunnels → Configure → Token |

## 5. Проверка

После деплоя cloudflared:
```bash
# Zero Trust Dashboard → Tunnels
# Статус: HEALTHY

# Проверить endpoint
curl https://api.yourdomain.com/health
```

## Безопасность

Cloudflare предоставляет:
- DDoS Protection (бесплатно)
- WAF Rules (бесплатно базовые)
- Bot Management (бесплатно базовый)
- TLS 1.3 (автоматически)
- Rate Limiting (5 бесплатных правил)

## Следующий шаг

[01-cloudflared-deployment.md](01-cloudflared-deployment.md)
