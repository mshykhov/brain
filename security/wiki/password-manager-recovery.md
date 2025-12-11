# Password Manager & Account Recovery

Архитектура восстановления доступа к критическим аккаунтам.

## Принципы

1. **Нет circular dependency** - recovery для Gmail НЕ в Google Drive
2. **3+ независимых способа** для каждого критического сервиса
3. **Без бумаги** - всё digital, encrypted
4. **4 пароля в голове** - максимум что нужно помнить

## Что помнить в голове

| # | Пароль | Для чего |
|---|--------|----------|
| 1 | Gmail password | Основной email |
| 2 | Keeper master password | Password manager |
| 3 | Encrypted archive password | Recovery файл (7-Zip) |
| 4 | Authy backup password | 2FA приложение |

> Proton Mail пароль хранится в Keeper (не circular, т.к. есть USB backup)

## Архитектура

```
УРОВЕНЬ 1: ЕЖЕДНЕВНЫЙ ДОСТУП
├── Gmail: password + YubiKey / Passkey
└── Keeper: master password + YubiKey / TOTP

УРОВЕНЬ 2: BACKUP 2FA
├── Gmail: TOTP в Authy + trusted device
└── Keeper: TOTP в Authy (обязательный backup)

УРОВЕНЬ 3: ENCRYPTED RECOVERY FILE
│
│  Содержимое (один 7-Zip AES-256):
│  ├── Keeper 24-word recovery phrase
│  ├── Gmail backup codes (10 шт)
│  ├── Authy recovery password
│  └── Proton Mail credentials
│
│  Где хранить:
│  ├── USB флешка дома
│  └── Proton Drive (НЕ Google!)
│
│  Пароль: В ГОЛОВЕ

УРОВЕНЬ 4: EMERGENCY
├── Gmail: recovery email (Proton) + phone
├── Keeper: biometrics (если залогинен)
└── Google: 3-5 дней верификации
```

## Keeper Recovery

### Официальные методы (docs.keeper.io)

| Метод | Когда работает |
|-------|----------------|
| Master Password + 2FA | Знаешь пароль |
| 24-word Recovery Phrase | Забыл пароль |
| Biometrics | Залогинен на устройстве |

### Требования Keeper

> "Keeper requires that users have a backup 2FA method using either TOTP, SMS, Duo, RSA or Keeper DNA"

Если потерял YubiKey - входишь через backup TOTP.

### Zero-Knowledge

- Keeper НЕ может восстановить твой vault
- Без master password + recovery phrase = данные утеряны навсегда
- AES-256 + PBKDF2 шифрование на устройстве

## Gmail Recovery

### Официальные методы (support.google.com)

| Метод | Приоритет | Риск |
|-------|-----------|------|
| Passkey | Основной | Зависит от устройства |
| Security Key | Основной | Потеря ключа |
| Google Prompts | 2FA | Нужен телефон |
| TOTP | 2FA | Зависит от устройства |
| Backup codes | Recovery | 10 одноразовых |
| Recovery email | Recovery | Нужен доступ |
| Recovery phone | Emergency | SIM-swap риск |

### Настройки

1. Passkey на телефоне (основной)
2. YubiKey 5 NFC (если есть)
3. TOTP в Authy (backup)
4. Backup codes в encrypted файле
5. Recovery email: Proton Mail
6. Recovery phone: твой номер

## Proton Mail

### Зачем нужен

- Recovery email для Gmail (независим от Google)
- Proton Drive для encrypted backup (не Google Drive)
- E2E encrypted

### Пароль

Хранится в Keeper. Это НЕ circular dependency потому что:
- Keeper recovery есть на USB (физически дома)
- Если Keeper недоступен → USB → encrypted file → Proton credentials

### Восстановление Proton

- Recovery email (другой)
- Recovery phrase (если включен)

## Authy

### Почему не Google Authenticator

> Google Authenticator cloud backup НЕ encrypted!

### Настройки Authy

- Encrypted backup: ВКЛ
- Backup password: отдельный (в голове)
- Multi-device: ВЫКЛ (безопаснее) или только на 2 устройства

## YubiKey

### Рекомендуемая модель

**YubiKey 5 NFC** (~$50) - USB-A + NFC, работает с телефоном и компьютером.

### Где использовать

- Keeper (primary 2FA)
- Gmail (primary 2FA)
- GitHub
- Другие критические сервисы

### Потеря YubiKey

Не критично если есть backup TOTP в Authy.

## Encrypted Recovery File

### Создание

```bash
# Содержимое файла recovery.txt:
# - Keeper 24-word phrase
# - Gmail backup codes
# - Authy backup password
# - Proton credentials

# Шифрование через 7-Zip
7z a -tzip -mem=AES256 -p recovery.7z recovery.txt

# Удалить оригинал
rm recovery.txt
```

### Хранение

| Копия | Локация |
|-------|---------|
| 1 | USB флешка дома |
| 2 | Proton Drive |

### Обновление

При генерации новых backup codes - обновить файл и обе копии.

## Чеклист настройки

- [ ] Создать Proton Mail аккаунт
- [ ] Установить Authy, настроить encrypted backup
- [ ] Gmail: добавить recovery email (Proton)
- [ ] Gmail: сгенерировать backup codes
- [ ] Gmail: настроить Passkey на телефоне
- [ ] Keeper: проверить TOTP backup в Authy
- [ ] Keeper: сохранить 24-word recovery phrase
- [ ] Создать encrypted 7-Zip с recovery данными
- [ ] Копия на USB
- [ ] Копия в Proton Drive
- [ ] (Опционально) Купить YubiKey 5 NFC

## Источники

- [Keeper Recovery Docs](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
- [Keeper 2FA Docs](https://docs.keeper.io/en/enterprise-guide/two-factor-authentication)
- [Google 2-Step Verification](https://support.google.com/accounts/answer/185839)
- [Google Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Yubico Store](https://www.yubico.com/store/compare/)
