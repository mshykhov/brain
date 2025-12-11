---
tags: [ssh, hardening, security]
status: pending
---

# SSH Hardening

## Зачем

SSH - первая точка входа на сервер. По умолчанию он уязвим к:
- Brute-force атакам на пароли
- Атакам на устаревшие алгоритмы шифрования
- Подключениям от любого IP

После настройки Tailscale SSH будет доступен только через него.

## Шаг 1: Создать SSH ключ (на локальной машине)

```bash
# Создать ED25519 ключ (современный, быстрый, безопасный)
ssh-keygen -t ed25519 -a 100 -C "myron@ovh-server"

# Ключ сохранится в:
# ~/.ssh/id_ed25519 (приватный - НИКОГДА не передавать)
# ~/.ssh/id_ed25519.pub (публичный - копируется на сервер)
```

**Сохрани приватный ключ в Keeper!**

## Шаг 2: Скопировать публичный ключ на сервер

```bash
# Вариант 1: через ssh-copy-id (если пароль ещё работает)
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server-ip

# Вариант 2: вручную
cat ~/.ssh/id_ed25519.pub
# На сервере добавить в ~/.ssh/authorized_keys
```

## Шаг 3: Настроить sshd_config

```bash
sudo nano /etc/ssh/sshd_config
```

```bash
# === Аутентификация ===
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 3

# === Пользователи ===
AllowUsers myron                    # только твой юзер

# === Сеть ===
Port 2222                           # сменить стандартный порт
AddressFamily inet                  # только IPv4 (или inet6 / any)
ListenAddress 0.0.0.0               # позже сменить на Tailscale IP

# === Таймауты ===
ClientAliveInterval 300
ClientAliveCountMax 2
LoginGraceTime 30

# === Криптография (2025) ===
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com

# === Отключить лишнее ===
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
```

## Шаг 4: Применить настройки

```bash
# Проверить синтаксис
sudo sshd -t

# Перезапустить SSH
sudo systemctl restart sshd
```

**ВАЖНО**: Не закрывай текущую сессию! Открой новый терминал и проверь что можешь подключиться.

## Шаг 5: Установить Fail2Ban

```bash
sudo apt update && sudo apt install fail2ban -y

# Создать локальную конфигурацию
sudo nano /etc/fail2ban/jail.local
```

```ini
[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
```

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Проверить статус
sudo fail2ban-client status sshd
```

## Шаг 6: Обновить ~/.ssh/config (локально)

```bash
# ~/.ssh/config
Host ovh
    HostName server-ip-or-tailscale-ip
    User myron
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
```

Теперь подключение: `ssh ovh`

## Проверка

- [ ] Вход по паролю отключен
- [ ] Root login отключен
- [ ] Только ED25519 ключи
- [ ] Нестандартный порт
- [ ] Fail2Ban работает
- [ ] SSH ключ сохранён в Keeper

## Ссылки

- [SSH Hardening Guides](https://www.sshaudit.com/hardening_guides.html)
- [OpenSSH Best Practices](https://www.cyberciti.biz/tips/linux-unix-bsd-openssh-server-best-practices.html)
