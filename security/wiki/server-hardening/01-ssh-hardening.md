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

```powershell
# Windows PowerShell
ssh-keygen -t ed25519 -a 100 -C "myron@ovh-server"

# Указать путь: C:\Users\Myron\.ssh\ovh-server
# Ввести passphrase (сохранить в Keeper!)
```

Ключи сохранятся:
- `~/.ssh/ovh-server` — приватный (НИКОГДА не передавать)
- `~/.ssh/ovh-server.pub` — публичный (копируется на сервер)

**Сохрани в Keeper**: приватный ключ + passphrase

## Шаг 1.5: Настроить ssh-agent (Windows)

```powershell
# В PowerShell (Administrator)
Set-Service -Name ssh-agent -StartupType Automatic
Start-Service ssh-agent

# В обычном терминале — добавить ключ
ssh-add $HOME\.ssh\ovh-server
# Ввести passphrase один раз
```

## Шаг 2: Скопировать публичный ключ на сервер

```powershell
# Показать публичный ключ (скопировать в буфер)
cat $HOME\.ssh\ovh-server.pub
```

На сервере:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Вставить публичный ключ, сохранить
chmod 600 ~/.ssh/authorized_keys
```

## Шаг 3: Настроить sshd_config

```bash
# Бэкап
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Перезаписать конфиг одной командой
sudo tee /etc/ssh/sshd_config << 'EOF'
Include /etc/ssh/sshd_config.d/*.conf
Port 2222
AddressFamily inet
ListenAddress 0.0.0.0

HostKey /etc/ssh/ssh_host_ed25519_key

PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
MaxAuthTries 3
MaxSessions 3
LoginGraceTime 30

AllowUsers ubuntu

ClientAliveInterval 300
ClientAliveCountMax 2

KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
HostKeyAlgorithms ssh-ed25519,ssh-ed25519-cert-v01@openssh.com

X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no
PermitUserEnvironment no

UsePAM yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
```

## Шаг 4: Применить настройки

```bash
sudo sshd -t && sudo systemctl daemon-reload && sudo systemctl restart ssh
```

**ВАЖНО**: Не закрывай текущую сессию! Открой новый терминал и проверь подключение:

```powershell
ssh -p 2222 -i $HOME\.ssh\ovh-server ubuntu@217.182.197.59
```

## Шаг 4.5: Добавить SSH config (Windows)

Добавить в `C:\Users\Myron\.ssh\config`:

```
Host ovh
    HostName 217.182.197.59
    User ubuntu
    Port 2222
    IdentityFile C:\Users\Myron\.ssh\ovh-server
```

Теперь подключение просто:
```powershell
ssh ovh
```

## Проверка

- [ ] Вход по паролю отключен
- [ ] Root login отключен
- [ ] Только ED25519 ключи
- [ ] Нестандартный порт (2222)
- [ ] SSH config настроен (Windows)
- [ ] Fail2Ban работает
- [ ] SSH ключ + passphrase сохранены в Keeper

## Ссылки

- [SSH Hardening Guides](https://www.sshaudit.com/hardening_guides.html)
- [OpenSSH Best Practices](https://www.cyberciti.biz/tips/linux-unix-bsd-openssh-server-best-practices.html)
