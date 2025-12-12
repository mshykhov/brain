# Password Manager & Account Recovery

Архитектура восстановления доступа к критическим аккаунтам.

> **Последнее обновление:** Декабрь 2024
> **Статус:** Актуально

## TL;DR — Независимые пути восстановления

### Keeper (3 независимых пути)

| # | Путь | Что нужно | Независимость |
|---|------|-----------|---------------|
| 1 | Нормальный вход | Master password + 2FA | Память + телефон |
| 2 | Recovery phrase | Phrase из encrypted file + email | USB/Cloud + email |
| 3 | Biometrics reset | Телефон с залогиненным Keeper | Только телефон |

### Gmail (4 независимых пути)

| # | Путь | Что нужно | Независимость |
|---|------|-----------|---------------|
| 1 | Нормальный вход | Password + 2FA | Память + телефон |
| 2 | Backup codes | Password + codes из encrypted file | Память + USB/Cloud |
| 3 | Recovery email | Доступ к Proton Mail | Proton аккаунт |
| 4 | Recovery phone | Доступ к номеру телефона | SIM-карта |

---

## Что реально работает (официальные источники)

| Сервис | Метод | Тип | Источник |
|--------|-------|-----|----------|
| Keeper | Master password + 2FA | Нормальный вход | docs.keeper.io |
| Keeper | Recovery phrase (24 слова BIP39) | Forgot password | docs.keeper.io |
| Keeper | Biometrics | Convenience (не DR) | docs.keeper.io |
| Gmail | Password + 2FA | Нормальный вход | support.google.com |
| Gmail | Password + Backup codes | Lost 2FA | support.google.com |
| Gmail | Recovery email/phone | Forgot password | support.google.com |
| Gmail | Passkey | Passwordless login | support.google.com |
| 2FAS/Aegis | Encrypted backup + password | Restore tokens | Локальный backup |

## Важные ограничения

### Biometrics — это НЕ disaster recovery

> "If you are able to log into Keeper's mobile app using Biometrics, you can reset your master password" — docs.keeper.io

**Требует:** телефон + Keeper app залогинен + biometrics работает.
**Если потерял телефон — не работает.**

### USB и Cloud — redundancy, не разные способы

Оба содержат один encrypted файл. Реальный способ один — содержимое файла.

### Google recovery без опций

> "If you still can't recover your account, you can create a new Google Account" — support.google.com

**Без recovery email/phone Google может отказать в восстановлении.**

---

## Архитектура восстановления

### Keeper

```
СПОСОБ 1: Нормальный вход
├── Master password (в голове)
└── 2FA: YubiKey ИЛИ TOTP

СПОСОБ 2: Forgot password flow
├── Recovery phrase (из encrypted файла)
├── Email verification
└── 2FA: backup метод

CONVENIENCE: Biometrics
├── Работает ТОЛЬКО если телефон у тебя и app залогинен
└── НЕ disaster recovery, но позволяет сбросить master password
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
├── Recovery email (Proton) ← независимый путь
├── Recovery phone ← независимый путь
└── 3-5 дней верификации Google

СПОСОБ 4: Passkey recovery (с сентября 2024)
├── Passkey синхронизирован в Google Password Manager
├── На новом устройстве: PIN от GPM ИЛИ screen lock старого Android
└── Passkey НЕ удаляет другие recovery методы
```

---

## Пароли в голове (только 3)

| # | Пароль | Критичность | Что теряешь если забыл |
|---|--------|-------------|------------------------|
| 1 | Gmail | Критичен | Email, recovery для сервисов |
| 2 | Keeper master | Критичен | Все пароли (но есть recovery phrase) |
| 3 | Archive (= Proton) | **САМЫЙ КРИТИЧНЫЙ** | Доступ к recovery data |

> **Archive password — единственный ключ к disaster recovery.**
> Без него USB и Proton бесполезны.

---

## TOTP приложения

### Authy — важные изменения 2024

> **Authy Desktop закрыт с марта 2024.** Twilio прекратил поддержку desktop-приложений. Authy теперь работает **только на мобильных устройствах** (iOS/Android).

> **Июнь 2024:** Утечка 33 млн телефонных номеров из Authy API. Номера могут использоваться для фишинга.

**Особенности Authy:**
- Encrypted backup в облаке Twilio
- Backup password хранится только локально — Twilio не может восстановить
- При восстановлении на новом устройстве: **24 часа ожидания** (security)
- Multi-device OFF = безопаснее, но сложнее recovery

### Альтернативы Authy

| Приложение | Desktop | Mobile | Export seeds | Open Source | Cloud sync |
|------------|---------|--------|--------------|-------------|------------|
| Authy | ❌ EOL | ✅ | ❌ | ❌ | ✅ (Twilio) |
| **2FAS** | ✅ browser | ✅ | ✅ | ✅ | ✅ (Google Drive) |
| **Aegis** (Android) | ❌ | ✅ | ✅ | ✅ | Manual backup |
| Raivo (iOS) | ❌ | ✅ | ✅ | ✅ | iCloud |
| KeePassXC | ✅ | ❌ | ✅ | ✅ | Manual |
| 1Password | ✅ | ✅ | ❌ | ❌ | ✅ (1Password) |

**Рекомендация:** 2FAS или Aegis — open source, позволяют экспорт seeds.

---

## Single Points of Failure (SPOF)

| SPOF | Риск | Mitigation |
|------|------|------------|
| Archive password забыт | Потеря всех recovery данных | Passphrase (легче запомнить) |
| Телефон потерян | Потеря TOTP + biometrics | Backup seeds в encrypted file |
| Proton заблокирован | Потеря cloud backup | USB backup |
| USB потерян/сломан | Потеря local backup | Proton backup |
| TOTP app закрыт/сломан | Потеря 2FA | Seeds в encrypted file |
| Multi-device OFF + потеря телефона | 24ч без TOTP | Backup codes / seeds |

---

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
          │ ├─ TOTP seeds   │ ← КРИТИЧНО     │
          │ └─ Proton 2FA   │                │
          └────────┬────────┘                │
                   │                         │
        ┌──────────┼──────────┐              │
        ▼          ▼          ▼              ▼
    ┌───────┐  ┌───────┐  ┌───────┐    ┌──────────┐
    │Keeper │  │ Gmail │  │ TOTP  │    │  Gmail   │
    │recover│  │backup │  │restore│    │ recovery │
    │       │  │ codes │  │       │    │  email   │
    └───────┘  └───────┘  └───────┘    └──────────┘
```

---

## Сценарии восстановления

### Сценарий 1: Забыл Keeper master password

```
ВАРИАНТ A (есть телефон):
1. Телефон с biometrics → Settings > Reset Master Password → DONE

ВАРИАНТ B (нет телефона):
1. USB или Proton → Decrypt file → Recovery phrase
2. Keeper: Forgot Password → Recovery phrase + email verification
3. 2FA: backup codes или seeds из файла → DONE
```

### Сценарий 2: Потерял телефон (TOTP + biometrics)

```
1. Новый телефон → Установить TOTP app (2FAS/Aegis/Authy)
2. USB или Proton → Decrypt file → TOTP seeds
3. Импортировать seeds в новый TOTP app → DONE
4. Теперь есть 2FA для входа в Keeper и Gmail

⚠️ Если используешь Authy без seeds:
   - authy.com/phones/reset → 24 часа ожидания
   - Backup password из encrypted file
```

### Сценарий 3: Потерял YubiKey

```
1. Keeper: вход через backup TOTP → DONE
2. Gmail: вход через backup TOTP или backup codes → DONE
3. Удалить потерянный ключ из настроек обоих сервисов
4. (Опционально) Добавить новый YubiKey
```

### Сценарий 4: Забыл Gmail password

```
ВАРИАНТ A (есть 2FA):
1. Gmail: Forgot password → Recovery email (Proton)
2. Или: Recovery phone (SMS/call)
3. 3-5 дней верификации → новый пароль → DONE

ВАРИАНТ B (нет 2FA device):
1. Gmail: Forgot password + Try another way
2. Backup codes из encrypted file → DONE
```

### Сценарий 5: Забыл Archive password (WORST CASE)

```
1. USB и Proton бесполезны (encrypted AES-256)
2. ЕСЛИ есть телефон с Keeper biometrics:
   → Войти в Keeper → сгенерировать новый recovery phrase
   → Войти в Gmail → сгенерировать новые backup codes
   → Создать новый encrypted file с новым паролем
3. ЕСЛИ нет телефона:
   → Gmail: recovery через phone/email (если настроены)
   → Keeper: ПОТЕРЯ ДАННЫХ (zero-knowledge)
```

### Сценарий 6: Пожар/кража (потеря USB + телефона)

```
1. Любое устройство → Proton Mail login
2. Proton Drive → Download encrypted file
3. Decrypt → recovery данные
4. Восстановить Keeper и Gmail по сценариям выше
```

---

## Содержимое Encrypted File

```
recovery.txt (внутри recovery.7z):

========================================
KEEPER
========================================
Recovery Phrase (24 words BIP39):
word1 word2 word3 word4 word5 word6
word7 word8 word9 word10 word11 word12
word13 word14 word15 word16 word17 word18
word19 word20 word21 word22 word23 word24

========================================
GMAIL
========================================
Backup Codes (8 цифр, одноразовые):
12345678
23456789
34567890
... (всего 10 кодов)

========================================
TOTP SEEDS (КРИТИЧНО!)
========================================
Keeper:  JBSWY3DPEHPK3PXP...
Gmail:   GEZDGNBVGY3TQOJQ...
Proton:  MFRGGZDFMY2TGNZR...

Формат для импорта в 2FAS/Aegis:
otpauth://totp/Keeper?secret=JBSWY3DPEHPK3PXP&issuer=Keeper
otpauth://totp/Gmail?secret=GEZDGNBVGY3TQOJQ&issuer=Google
otpauth://totp/Proton?secret=MFRGGZDFMY2TGNZR&issuer=Proton

========================================
PROTON
========================================
Email: your-email@proton.me
Password: [same as archive - это напоминание]
2FA seed: MFRGGZDFMY2TGNZR...

========================================
AUTHY (если используется)
========================================
Backup Password: [password]
Phone number: +1234567890
```

---

## Безопасность схемы

### Защита от угроз

| Угроза | Защита |
|--------|--------|
| Взлом Keeper серверов | Zero-knowledge, AES-256 |
| Взлом Proton | Файл encrypted (AES-256) |
| Кража USB | Файл encrypted |
| SIM-swap | Нет SMS 2FA для критичных сервисов |
| Потеря телефона | USB + Proton backup + seeds |
| Потеря USB | Proton backup |
| Потеря Proton | USB backup |
| TOTP app закрылся | Seeds в encrypted file |

### Оставшиеся риски

| Риск | Вероятность | Impact | Mitigation |
|------|-------------|--------|------------|
| Забыть archive password | Низкая | Критичный | Passphrase + регулярное использование |
| Пожар + Proton down | Очень низкая | Критичный | Второй USB у родственника |
| Компрометация Proton | Низкая | Низкий | Файл зашифрован |
| Физический доступ к USB | Низкая | Низкий | Файл зашифрован |

---

## Чеклист настройки

### Proton Mail
- [ ] Создать аккаунт Proton Mail
- [ ] Пароль = Archive password (запомнить!)
- [ ] Включить 2FA (TOTP)
- [ ] **Сохранить TOTP seed в encrypted file**
- [ ] Создать Proton Drive

### TOTP App (2FAS / Aegis рекомендуется)
- [ ] Установить 2FAS или Aegis
- [ ] Включить encrypted backup (опционально)
- [ ] Добавить TOTP: Keeper, Gmail, Proton
- [ ] **Экспортировать seeds → сохранить в encrypted file**

### Gmail
- [ ] Recovery email: Proton Mail
- [ ] Recovery phone: твой номер
- [ ] 2FA: TOTP + Passkey
- [ ] Сгенерировать Backup Codes (10 шт)
- [ ] **Сохранить backup codes в encrypted file**
- [ ] **Сохранить TOTP seed в encrypted file**
- [ ] (Опционально) YubiKey

### Keeper
- [ ] Включить 2FA: TOTP
- [ ] (Опционально) YubiKey
- [ ] Сгенерировать Recovery Phrase (24 слова)
- [ ] **Сохранить phrase в encrypted file**
- [ ] **Сохранить TOTP seed в encrypted file**
- [ ] Включить Biometrics на телефоне

### Encrypted File
- [ ] Создать recovery.txt со всеми данными
- [ ] Зашифровать: `7z a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p recovery.7z recovery.txt`
- [ ] Безопасно удалить recovery.txt
- [ ] Копия 1: USB дома
- [ ] Копия 2: Proton Drive
- [ ] **Проверить расшифровку на обеих копиях**

### Тестирование (раз в 6 месяцев)
- [ ] Расшифровать файл с USB
- [ ] Убедиться что все данные читаемы
- [ ] Проверить что backup codes не использованы
- [ ] Обновить если добавились новые сервисы

---

## Источники

### Keeper
- [Master Password Reset & Recovery](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
- [Two-Factor Authentication](https://docs.keeper.io/en/enterprise-guide/two-factor-authentication)

### Google
- [2-Step Verification](https://support.google.com/accounts/answer/185839)
- [Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Account Recovery](https://support.google.com/accounts/answer/7682439)
- [Passkeys](https://support.google.com/accounts/answer/13548313)
- [Google Password Manager Passkeys (Sept 2024)](https://blog.google/technology/safety-security/google-password-manager-passkeys-update-september-2024/)

### Authy / TOTP
- [Authy: Restoring Access](https://www.authy.com/phones/reset/)
- [Authy Desktop EOL (March 2024)](https://www.twilio.com/en-us/changelog/end-of-life--eol--of-twilio-authy-desktop-apps)
- [2FAS](https://2fas.com/)
- [Aegis Authenticator](https://getaegis.app/)
