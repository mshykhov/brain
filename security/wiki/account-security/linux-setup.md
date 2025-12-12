# Linux Setup

Настройки безопасности Linux (Ubuntu/Debian-based).

## 1. Обновления

```bash
# Включи автоматические security updates
sudo apt update && sudo apt upgrade -y
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades  # выбери Yes
```

---

## 2. Firewall

```bash
# UFW (Uncomplicated Firewall)
sudo apt install ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status
```

---

## 3. YubiKey

### Установка

```bash
# Yubico Authenticator (Flatpak - рекомендуется)
flatpak install flathub com.yubico.yubioath

# Или через apt (может быть старая версия)
sudo apt install yubikey-manager
```

### udev rules (для работы без root)

```bash
# Добавь правила для YubiKey
sudo apt install libpam-u2f
# Правила обычно добавляются автоматически
# Если нет:
wget https://raw.githubusercontent.com/Yubico/libu2f-host/master/70-u2f.rules
sudo mv 70-u2f.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### Использование

```bash
# TOTP
yubioath-desktop  # или flatpak run com.yubico.yubioath

# Вставь YubiKey → коды появятся автоматически
```

---

## 4. Chrome/Firefox

### Chrome

```bash
# Установи из официального репо
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i google-chrome-stable_current_amd64.deb
```

Настройки те же что в [Windows Setup](windows-setup.md):
- Enhanced Safe Browsing
- HTTPS-Only
- DBSC в chrome://flags

### Firefox

```
Settings → Privacy & Security:
├── Enhanced Tracking Protection: Strict
├── HTTPS-Only Mode: Enable in all windows
└── Passwords: Don't save (используй Keeper)
```

---

## 5. Keeper

### Установка

```bash
# Скачай .deb с keepersecurity.com
wget https://keepersecurity.com/desktop_electron/Linux/keeper.deb
sudo dpkg -i keeper.deb

# Или через Snap
sudo snap install keeper-password-manager
```

### Browser Extension

Установи из Chrome Web Store или Firefox Add-ons.

---

## 6. Encrypted file (7z)

### Установка

```bash
sudo apt install p7zip-full
```

### Создание

```bash
# Зашифровать
7z a -t7z -m0=lzma2 -mhe=on -p recovery.7z recovery.txt

# -mhe=on шифрует имена файлов
# Пароль введёшь интерактивно
```

### Расшифровка

```bash
7z x recovery.7z
# Введи пароль
```

### Безопасное удаление

```bash
shred -u recovery.txt
# или
srm recovery.txt  # если установлен secure-delete
```

---

## 7. Disk Encryption (LUKS)

Если не включил при установке:

```bash
# Проверь статус
lsblk -f

# Для новых дисков:
sudo cryptsetup luksFormat /dev/sdX
sudo cryptsetup open /dev/sdX encrypted_disk
sudo mkfs.ext4 /dev/mapper/encrypted_disk
```

**Рекомендация:** Включи Full Disk Encryption при установке системы.

---

## Чеклист

### Система
- [ ] Автообновления включены
- [ ] UFW firewall включен
- [ ] Disk encryption (LUKS) включен

### YubiKey
- [ ] Yubico Authenticator установлен
- [ ] udev rules настроены
- [ ] YubiKey работает без sudo

### Apps
- [ ] Keeper установлен
- [ ] Browser extension установлен
- [ ] 7z установлен

### Browser
- [ ] Enhanced Safe Browsing / Strict mode
- [ ] HTTPS-Only
- [ ] Password manager отключен

---

## Источники

- [YubiKey Linux](https://support.yubico.com/hc/en-us/articles/360013708900-Using-Your-YubiKey-with-Linux)
- [Ubuntu Security](https://ubuntu.com/security)
- [UFW Guide](https://help.ubuntu.com/community/UFW)
