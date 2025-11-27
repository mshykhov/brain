# Phase 0: Tailscale SSH

Доступ к серверу через Tailscale.

## Установка (на сервере)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

Перейди по ссылке → залогинься.

## Подключение (с локальной машины)

```bash
ssh user@hostname
```

Где `hostname` — имя машины в Tailscale (видно в https://login.tailscale.com/admin/machines).

## Проверка

```bash
tailscale status
tailscale ip -4
```

## Следующий шаг

[Phase 1: ArgoCD](../phase1/argocd.md)
