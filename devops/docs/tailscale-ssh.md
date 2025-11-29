# Tailscale SSH

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

## Kubeconfig через Tailscale

Настройка kubectl для подключения к Kubernetes через Tailscale Operator:

```bash
sudo tailscale configure kubeconfig tailscale-operator
```

## Смена аккаунта

Посмотреть все аккаунты:

```bash
tailscale switch --list
```

Добавить новый аккаунт:

```bash
sudo tailscale login
```

Переключиться на другой аккаунт:

```bash
sudo tailscale switch <account-id>
```

Задать никнейм для текущего аккаунта:

```bash
sudo tailscale set --nickname=main
```

Переключаться по никнейму:

```bash
sudo tailscale switch main
```

Алиас для быстрой смены (добавить в ~/.bashrc):

```bash
alias ts-switch='sudo tailscale up --force-reauth --accept-routes --ssh'
```
