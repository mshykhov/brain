# Password Manager & Account Recovery

Архитектура восстановления доступа к критическим аккаунтам.

## Критический анализ

### Что реально работает (по официальным docs)

| Сервис | Метод | Тип | Официально подтверждено |
|--------|-------|-----|-------------------------|
| Keeper | Master password + 2FA | Нормальный вход | docs.keeper.io |
| Keeper | Recovery phrase + 2FA | Forgot password | docs.keeper.io |
| Keeper | Biometrics | **Convenience bypass** | docs.keeper.io |
| Gmail | Password + 2FA | Нормальный вход | support.google.com |
| Gmail | Password + Backup codes | Lost 2FA device | support.google.com |
| Gmail | Recovery email/phone | Forgot password (3-5 дней) | support.google.com |
| Gmail | Trusted device | Bypass 2FA | support.google.com |
| Authy | Backup password | Restore на новом устройстве | support.authy.com |

### Важные ограничения

**Biometrics — это НЕ disaster recovery:**
> "If you are able to log into Keeper's mobile app using Biometrics, you can reset your master password" — docs.keeper.io

Требует: телефон + Keeper app залогинен + biometrics работает.
Если потерял телефон — не работает.

**USB и Cloud — это redundancy, не разные способы:**
Оба содержат один encrypted файл. Реальный способ один — recovery phrase.

**Google recovery без опций:**
> "If you still can't recover your account, you can create a new Google Account" — support.google.com

Без recovery email/phone Google может отказать в восстановлении.

## Реальная архитектура (2 способа, не 3)

### Keeper

```
СПОСОБ 1: Нормальный вход
├── Master password (в голове)
└── 2FA: YubiKey ИЛИ TOTP (Authy)

СПОСОБ 2: Forgot password flow
├── Recovery phrase (из encrypted файла)
├── Email verification
└── 2FA: backup метод

CONVENIENCE: Biometrics
└── Работает ТОЛЬКО если телефон у тебя и app залогинен
└── НЕ disaster recovery
```

### Gmail

```
СПОСОБ 1: Нормальный вход
├── Password (в голове)
└── 2FA: YubiKey / TOTP / Passkey

СПОСОБ 2: Lost 2FA device
├── Password (в голове)
└── Backup codes (из encrypted файла)

СПОСОБ 3: Forgot password
├── Recovery email (Proton)
├── Recovery phone
└── 3-5 дней верификации Google

CONVENIENCE: Trusted device
└── Если ранее отметил "Don't ask again"
```

## Пароли в голове

| # | Пароль | Критичность | Что теряешь если забыл |
|---|--------|-------------|------------------------|
| 1 | Gmail | Критичен | Email, recovery для других сервисов |
| 2 | Keeper master | Критичен | Все пароли (но есть recovery phrase) |
| 3 | Archive = Proton | **САМЫЙ КРИТИЧНЫЙ** | Доступ к recovery phrase и backup codes |

> **Archive password — единственный ключ к disaster recovery.**
> Без него USB и Proton бесполезны.

## Single Points of Failure (SPOF)

| SPOF | Риск | Mitigation |
|------|------|------------|
| Archive password забыт | Потеря recovery phrase | Использовать passphrase (легче запомнить) |
| Телефон потерян | Потеря Authy + biometrics | USB/Proton backup, Authy backup password в файле |
| Proton заблокирован | Потеря cloud backup | USB backup существует |
| USB потерян/сломан | Потеря local backup | Proton backup существует |
| Authy сервис закрыт | Потеря TOTP | Хранить seeds в encrypted файле |

## Схема зависимостей

```
                    ┌─────────────────┐
                    │ Archive Password│ ← В ГОЛОВЕ (критичен!)
                    │   = Proton pwd  │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌─────────┐   ┌───────────┐   ┌─────────────┐
        │   USB   │   │  Proton   │   │   Proton    │
        │ (дома)  │   │   Drive   │   │    Mail     │
        └────┬────┘   └─────┬─────┘   └──────┬──────┘
             │              │                │
             └──────┬───────┘                │
                    ▼                        │
          ┌─────────────────┐                │
          │ Encrypted File  │                │
          │ ├─ Keeper phrase│                │
          │ ├─ Gmail codes  │                │
          │ ├─ Authy pwd    │                │
          │ └─ Proton creds │                │
          └────────┬────────┘                │
                   │                         │
        ┌──────────┼──────────┐              │
        ▼          ▼          ▼              ▼
    ┌───────┐  ┌───────┐  ┌───────┐    ┌──────────┐
    │Keeper │  │ Gmail │  │ Authy │    │  Gmail   │
    │recover│  │backup │  │restore│    │ recovery │
    │       │  │ codes │  │       │    │  email   │
    └───────┘  └───────┘  └───────┘    └──────────┘
```

## Сценарии восстановления

### Сценарий 1: Забыл Keeper master password
```
1. Телефон с biometrics? → Settings > Reset Master Password → DONE
2. Нет телефона? → USB или Proton → Encrypted file → Recovery phrase
3. Keeper: Forgot Password → Recovery phrase + email + 2FA → DONE
```

### Сценарий 2: Потерял телефон (Authy + biometrics)
```
1. Новый телефон → Установить Authy
2. USB или Proton → Encrypted file → Authy backup password
3. Authy: Restore from backup → DONE
4. Теперь есть 2FA для входа в Keeper и Gmail
```

### Сценарий 3: Потерял YubiKey
```
1. Keeper: вход через backup TOTP (Authy) → DONE
2. Gmail: вход через backup TOTP или backup codes → DONE
3. Удалить потерянный ключ из настроек
```

### Сценарий 4: Забыл Archive password (WORST CASE)
```
1. USB и Proton бесполезны (encrypted)
2. Если есть телефон с Keeper biometrics → можно войти и пересоздать recovery
3. Если нет телефона → ПОТЕРЯ ДАННЫХ (Keeper zero-knowledge)
```

## Содержимое Encrypted File

```
recovery.txt (внутри recovery.7z):

=== KEEPER ===
Recovery Phrase: word1 word2 word3 ... word24

=== GMAIL ===
Backup Codes:
1234 5678
2345 6789
... (10 кодов)

=== AUTHY ===
Backup Password: [password]

=== PROTON ===
Email: [email]
Password: [same as archive - reminder]

=== TOTP SEEDS (опционально) ===
Keeper: ABCD1234...
Gmail: EFGH5678...
(на случай если Authy закроется)
```

## Безопасность схемы

### Что защищено

| Угроза | Защита |
|--------|--------|
| Взлом Keeper серверов | Zero-knowledge, AES-256 |
| Взлом Proton | Файл encrypted (AES-256) |
| Кража USB | Файл encrypted |
| SIM-swap | Нет SMS 2FA, только TOTP/YubiKey |
| Потеря телефона | USB + Proton backup |
| Потеря USB | Proton backup |
| Потеря Proton | USB backup |

### Оставшиеся риски

| Риск | Вероятность | Impact |
|------|-------------|--------|
| Забыть archive password | Низкая (passphrase) | Критичный |
| Пожар/кража дома + Proton down | Очень низкая | Критичный |
| Authy закроется без предупреждения | Низкая | Средний (есть seeds) |

## Чеклист настройки

### Proton
- [ ] Создать Proton Mail аккаунт
- [ ] Пароль = Archive password (запомнить!)
- [ ] Включить 2FA (TOTP в Authy)
- [ ] Создать Proton Drive

### Authy
- [ ] Установить Authy
- [ ] Включить Encrypted Backup
- [ ] Установить Backup Password (записать в encrypted file)
- [ ] Multi-device: OFF (безопаснее)
- [ ] Добавить TOTP: Keeper, Gmail, Proton

### Gmail
- [ ] Recovery email: Proton Mail
- [ ] Recovery phone: твой номер
- [ ] 2FA: TOTP (Authy) + Passkey на телефоне
- [ ] Сгенерировать Backup Codes (10 шт)
- [ ] (Опционально) YubiKey

### Keeper
- [ ] Включить 2FA: TOTP (Authy) как backup
- [ ] (Опционально) YubiKey как primary
- [ ] Сгенерировать Recovery Phrase
- [ ] Включить Biometrics на телефоне

### Encrypted File
- [ ] Создать recovery.txt со всеми данными
- [ ] `7z a -tzip -mem=AES256 -p recovery.7z recovery.txt`
- [ ] Удалить recovery.txt
- [ ] Копия 1: USB дома
- [ ] Копия 2: Proton Drive
- [ ] Проверить расшифровку на обеих копиях

## Источники

- [Keeper: Master Password Reset & Recovery](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
- [Keeper: Two-Factor Authentication](https://docs.keeper.io/en/enterprise-guide/two-factor-authentication)
- [Google: 2-Step Verification](https://support.google.com/accounts/answer/185839)
- [Google: Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Google: Account Recovery](https://support.google.com/accounts/answer/7682439)
- [Authy: Restoring Access](https://help.twilio.com/articles/19753413578523-Restoring-Authy-Access-on-a-New-Lost-or-Inaccessible-Phone)
