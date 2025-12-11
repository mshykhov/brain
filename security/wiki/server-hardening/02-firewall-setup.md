---
tags: [firewall, ufw, security]
status: pending
---

# Firewall Setup (UFW)

## Зачем

Закрыть все порты кроме необходимых. После настройки Tailscale — SSH и k3s API будут доступны только через Tailscale.

## Стратегия

1. **Сейчас**: открыть только SSH (2222)
2. **После Tailscale**: SSH только через Tailscale IP
3. **k3s**: API (6443) только через Tailscale

## Шаг 1: Установить UFW

```bash
sudo apt update && sudo apt install ufw -y
```

## Шаг 2: Базовые правила

```bash
# Сбросить к дефолтам
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Разрешить SSH (ВАЖНО: сначала это, потом enable!)
sudo ufw allow 2222/tcp comment 'SSH'
```

## Шаг 3: Включить UFW

```bash
sudo ufw enable

# Проверить статус
sudo ufw status verbose
```

## Шаг 4: После установки Tailscale

Когда Tailscale работает, ограничить SSH только Tailscale сетью:

```bash
# Узнать Tailscale IP сервера
tailscale ip -4

# Разрешить SSH только из Tailscale (100.x.x.x)
sudo ufw allow from 100.64.0.0/10 to any port 2222 proto tcp comment 'SSH via Tailscale'

# Удалить публичный доступ к SSH
sudo ufw delete allow 2222/tcp

# Проверить
sudo ufw status numbered
```

## Шаг 5: Правила для k3s (после установки k3s)

```bash
# k3s API — только через Tailscale
sudo ufw allow from 100.64.0.0/10 to any port 6443 proto tcp comment 'k3s API via Tailscale'

# Pod и Service сети (локально)
sudo ufw allow from 10.42.0.0/16 comment 'k3s pods'
sudo ufw allow from 10.43.0.0/16 comment 'k3s services'
```

## Проверка

```bash
sudo ufw status verbose
```

Должно быть:
```
Status: active
Default: deny (incoming), allow (outgoing)

To                         Action      From
--                         ------      ----
2222/tcp                   ALLOW       100.64.0.0/10    # SSH via Tailscale
6443/tcp                   ALLOW       100.64.0.0/10    # k3s API via Tailscale
Anywhere                   ALLOW       10.42.0.0/16     # k3s pods
Anywhere                   ALLOW       10.43.0.0/16     # k3s services
```

## Чеклист

- [ ] UFW установлен и включен
- [ ] SSH открыт на 2222
- [ ] После Tailscale: SSH только через 100.64.0.0/10
- [ ] k3s порты только через Tailscale

## Ссылки

- [K3s Requirements - Networking](https://docs.k3s.io/installation/requirements)
- [K3s with UFW Discussion](https://github.com/k3s-io/k3s/discussions/7319)
