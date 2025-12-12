# Password Manager & Account Recovery

Архитектура восстановления доступа к критическим аккаунтам.

> **Последнее обновление:** Декабрь 2024
> **Принцип:** 3+ независимых пути восстановления для каждого сервиса

---

## TL;DR

```
3 пароля в голове
2 YubiKey (primary + backup)
1 USB + 1 Cloud
= 3+ независимых пути восстановления
```

### Keeper: 3 независимых пути

| # | Путь | Что нужно | Категория |
|---|------|-----------|-----------|
| 1 | Нормальный вход | Master pwd + YubiKey | Память + Hardware |
| 2 | Recovery phrase | Archive pwd + USB/Cloud | Память + Digital |
| 3 | Biometrics | Телефон с Keeper | Device |

### Gmail: 4 независимых пути

| # | Путь | Что нужно | Категория |
|---|------|-----------|-----------|
| 1 | Нормальный вход | Gmail pwd + YubiKey | Память + Hardware |
| 2 | Backup codes | Gmail pwd + Archive pwd | Память + Digital |
| 3 | Recovery email | Archive pwd (Proton) | Digital |
| 4 | Recovery phone | SIM карта | Physical |

---

## Что нужно запомнить и купить

### 3 пароля в голове

| # | Пароль | Для чего | Критичность |
|---|--------|----------|-------------|
| 1 | Gmail | Вход в Gmail | Высокая |
| 2 | Keeper master | Вход в Keeper | Высокая |
| 3 | Archive = Proton | Encrypted file + Proton Mail | **Критичная** |

> **Совет:** Используй passphrase (4-5 случайных слов) — легче запомнить, сложнее взломать.

### Hardware: 2x YubiKey 5 NFC

| Ключ | Где хранить | Содержит |
|------|-------------|----------|
| Primary | С собой (ключи/кошелёк) | FIDO2 + TOTP seeds |
| Backup | Дома | FIDO2 + TOTP seeds |

**Почему YubiKey 5 NFC:**
- FIDO2/WebAuthn — phishing-resistant (лучше TOTP)
- TOTP storage — 32-64 слота для seeds
- NFC — работает с телефоном
- USB-A — работает с компьютером
- ~$55 за штуку, $110 за пару

### Storage: 1 USB + 1 Cloud

| Хранилище | Где | Что содержит |
|-----------|-----|--------------|
| USB | Дома | Encrypted file (Archive pwd) |
| Proton Drive | Cloud | Encrypted file (Archive pwd) |

---

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    3 ПАРОЛЯ В ГОЛОВЕ                        │
├───────────────────┬───────────────────┬─────────────────────┤
│      Gmail        │   Keeper master   │  Archive = Proton   │
└─────────┬─────────┴─────────┬─────────┴──────────┬──────────┘
          │                   │                    │
          ▼                   ▼                    ▼
┌─────────────────────────────────────────────────────────────┐
│                    2x YUBIKEY                               │
├─────────────────────────────┬───────────────────────────────┤
│   Primary (с собой)         │   Backup (дома)               │
│   ├─ FIDO2: Gmail, Keeper   │   ├─ FIDO2: Gmail, Keeper     │
│   └─ TOTP: Proton + backup  │   └─ TOTP: Proton + backup    │
└─────────────────────────────┴───────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    1 USB + 1 CLOUD                          │
├─────────────────────────────┬───────────────────────────────┤
│   USB (дома)                │   Proton Drive + Mail         │
│   └─ encrypted file         │   ├─ encrypted file           │
│      (Archive pwd)          │   │  (Archive pwd)            │
│                             │   └─ Proton Mail              │
│   Содержит:                 │      (Archive pwd)            │
│   ├─ Keeper recovery phrase │      → Gmail recovery email   │
│   ├─ Gmail backup codes     │                               │
│   └─ TOTP seeds             │                               │
└─────────────────────────────┴───────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              НЕЗАВИСИМЫЕ ПУТИ (без паролей!)                │
├─────────────────────────────┬───────────────────────────────┤
│   Recovery phone            │   Keeper biometrics           │
│   → Gmail recovery          │   → Keeper access             │
│   (нужна только SIM)        │   (нужен только телефон)      │
└─────────────────────────────┴───────────────────────────────┘
```

---

## Матрица независимости

### Keeper: что если потерял X?

| Потерял | Path 1 (pwd+key) | Path 2 (file) | Path 3 (bio) | Результат |
|---------|------------------|---------------|--------------|-----------|
| Забыл Master pwd | ❌ | ✅ | ✅ | OK |
| Потерял оба YubiKey | ✅ TOTP app | ✅ | ✅ | OK |
| Забыл Archive pwd | ✅ | ❌ | ✅ | OK |
| Потерял телефон | ✅ | ✅ | ❌ | OK |
| Пожар (USB сгорел) | ✅ | ✅ cloud | ✅ | OK |

### Gmail: что если потерял X?

| Потерял | Path 1 (pwd+key) | Path 2 (codes) | Path 3 (email) | Path 4 (phone) | Результат |
|---------|------------------|----------------|----------------|----------------|-----------|
| Забыл Gmail pwd | ❌ | ❌ | ✅ | ✅ | OK |
| Потерял оба YubiKey | ✅ TOTP | ✅ | ✅ | ✅ | OK |
| Забыл Archive pwd | ✅ | ❌ | ❌ | ✅ | OK |
| Потерял телефон+SIM | ✅ | ✅ | ✅ | ❌ | OK |

---

## Сценарии восстановления

### Сценарий 1: Забыл Keeper master password

```
ВАРИАНТ A — есть телефон с Keeper:
1. Открыть Keeper → биометрия (Face ID / отпечаток)
2. Settings → Reset Master Password
3. Создать новый master password → DONE

ВАРИАНТ B — нет телефона:
1. USB или Proton Drive → скачать encrypted file
2. Расшифровать (Archive pwd) → получить recovery phrase
3. Keeper → Forgot Password → ввести recovery phrase
4. Подтвердить email + 2FA → DONE
```

### Сценарий 2: Забыл Gmail password

```
ВАРИАНТ A — recovery phone:
1. Gmail → Forgot password
2. Google отправит код на recovery phone
3. Ввести код → создать новый пароль → DONE

ВАРИАНТ B — recovery email:
1. Gmail → Forgot password → Try another way
2. Google отправит код на Proton Mail
3. Войти в Proton (Archive pwd) → получить код
4. Ввести код → создать новый пароль → DONE

ВАРИАНТ C — backup codes:
1. Gmail → войти с паролем → нужен 2FA
2. Try another way → Enter backup code
3. USB/Proton → encrypted file → backup codes
4. Ввести код → DONE
```

### Сценарий 3: Потерял телефон (YubiKey + TOTP + biometrics)

```
1. Есть backup YubiKey дома? → использовать его → DONE

2. Нет backup YubiKey?
   ├─ Gmail: backup codes из encrypted file
   ├─ Keeper: recovery phrase из encrypted file
   └─ Новый телефон → восстановить TOTP из seeds в файле
```

### Сценарий 4: Потерял YubiKey (оба)

```
1. TOTP app на телефоне работает? → использовать TOTP → DONE
2. Нет TOTP? → backup codes / recovery phrase из encrypted file
3. После восстановления доступа:
   └─ Купить новые YubiKey → настроить заново
```

### Сценарий 5: Забыл Archive password (CRITICAL)

```
1. Gmail: recovery phone работает (не нужен Archive pwd) → OK
2. Keeper: biometrics работает (не нужен Archive pwd) → OK
3. После входа:
   ├─ Keeper: сгенерировать НОВЫЙ recovery phrase
   ├─ Gmail: сгенерировать НОВЫЕ backup codes
   ├─ Создать НОВЫЙ encrypted file с НОВЫМ Archive pwd
   └─ Сохранить на USB + Proton Drive
```

### Сценарий 6: Пожар/кража (потеря USB + телефона)

```
1. Любое устройство → proton.me → войти (Archive pwd)
2. Proton Drive → скачать encrypted file
3. Расшифровать → recovery данные
4. Восстановить доступ к Gmail и Keeper
5. Новый телефон → настроить TOTP из seeds
6. Купить новые YubiKey
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
45678901
56789012
67890123
78901234
89012345
90123456
01234567

========================================
TOTP SEEDS
========================================
Формат для импорта в любой TOTP app:

Proton:
otpauth://totp/Proton:user@proton.me?secret=XXXXXXXX&issuer=Proton

Keeper (если не используется YubiKey как primary):
otpauth://totp/Keeper:user@email.com?secret=XXXXXXXX&issuer=Keeper

========================================
PROTON (напоминание)
========================================
Email: your-email@proton.me
Password: = Archive password (тот же)
```

---

## TOTP: YubiKey vs App

### Когда использовать YubiKey TOTP

```
Основной способ:
├─ Gmail: FIDO2 (YubiKey) — phishing-resistant
├─ Keeper: FIDO2 (YubiKey) — phishing-resistant
└─ Proton: TOTP (YubiKey) — Proton не поддерживает FIDO2 для логина
```

### Когда использовать TOTP App (2FAS/Aegis)

```
Backup от YubiKey:
├─ Если потерял оба YubiKey
├─ Если YubiKey не работает с устройством
└─ Seeds хранятся в encrypted file для восстановления
```

### Рекомендуемый TOTP App

| App | Platform | Export seeds | Open Source |
|-----|----------|--------------|-------------|
| **2FAS** | iOS/Android/Browser | ✅ | ✅ |
| **Aegis** | Android | ✅ | ✅ |
| Raivo | iOS | ✅ | ✅ |

**Authy не рекомендуется:**
- Desktop закрыт (март 2024)
- Нельзя экспортировать seeds
- Утечка 33M номеров (июнь 2024)

---

## Безопасность

### Защита от угроз

| Угроза | Защита |
|--------|--------|
| Фишинг | YubiKey FIDO2 — immune to phishing |
| Взлом Keeper/Gmail серверов | Zero-knowledge (Keeper), E2E (нет паролей на сервере) |
| Взлом Proton | Encrypted file защищён AES-256 |
| Кража USB | Encrypted file защищён AES-256 |
| SIM-swap | Нет SMS для 2FA, только YubiKey/TOTP |
| Потеря телефона | YubiKey + encrypted file backup |
| Потеря YubiKey | Backup YubiKey + TOTP seeds |
| Пожар дома | Proton Drive cloud backup |

### Single Points of Failure

| SPOF | Mitigation |
|------|------------|
| Archive password | Recovery phone + biometrics работают без него |
| Оба YubiKey | TOTP app + backup codes |
| Телефон | YubiKey + encrypted file |
| Proton down | USB backup дома |
| USB сломался | Proton Drive backup |

---

## Чеклист настройки

### 1. Proton Mail + Drive
- [ ] Создать аккаунт proton.me
- [ ] Пароль = Archive password (запомнить!)
- [ ] Включить 2FA → сохранить TOTP seed
- [ ] Proton Drive создаётся автоматически

### 2. YubiKey (x2)
- [ ] Купить 2x YubiKey 5 NFC (~$110)
- [ ] Настроить primary YubiKey:
  - [ ] Gmail: Security → 2-Step Verification → Security Key
  - [ ] Keeper: Settings → Security → Security Key
  - [ ] Добавить TOTP для Proton (Yubico Authenticator)
- [ ] Настроить backup YubiKey (те же шаги, тот же момент!)
- [ ] Primary носить с собой, Backup хранить дома

### 3. Gmail
- [ ] Recovery email: Proton Mail адрес
- [ ] Recovery phone: твой номер
- [ ] 2-Step Verification:
  - [ ] Security Key (YubiKey) — primary
  - [ ] Passkey на телефоне — backup
- [ ] Сгенерировать Backup Codes (10 шт) → сохранить!

### 4. Keeper
- [ ] Security Key (YubiKey) — primary 2FA
- [ ] TOTP — backup 2FA (если нужно)
- [ ] Recovery Phrase → сгенерировать и сохранить!
- [ ] Biometrics на телефоне — включить

### 5. Encrypted File
- [ ] Создать `recovery.txt`:
  - [ ] Keeper recovery phrase
  - [ ] Gmail backup codes
  - [ ] TOTP seeds (otpauth:// URLs)
- [ ] Зашифровать:
  ```bash
  7z a -t7z -m0=lzma2 -mx=9 -mhe=on -p recovery.7z recovery.txt
  ```
- [ ] Безопасно удалить `recovery.txt`:
  ```bash
  # Linux/macOS:
  shred -u recovery.txt
  # Windows:
  cipher /w:. && del recovery.txt
  ```
- [ ] Копия на USB
- [ ] Копия на Proton Drive
- [ ] **Проверить:** расшифровать обе копии и убедиться что данные читаемы

### 6. Тестирование (раз в 6 месяцев)
- [ ] Расшифровать файл с USB
- [ ] Проверить что backup codes актуальны (не использованы)
- [ ] Проверить что recovery phrase работает (не тестировать реально, просто убедиться что читаем)
- [ ] Swap YubiKey — использовать backup неделю, убедиться что работает

---

## Hardware: сравнение ключей

| Ключ | TOTP | FIDO2 | Passkeys | Цена | Вердикт |
|------|------|-------|----------|------|---------|
| **YubiKey 5 NFC** | ✅ 32-64 | ✅ | 25 | $55 | **Лучший выбор** |
| YubiKey 5C NFC | ✅ 32-64 | ✅ | 25 | $55 | Для USB-C only |
| Google Titan | ❌ | ✅ | 250 | $30 | Нет TOTP! |
| Thetis Pro | ❌ | ✅ | 50 | $40 | Нет TOTP! |

**Для TOTP + FIDO2:** только YubiKey 5 series.

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

### YubiKey
- [YubiKey 5 Series](https://www.yubico.com/products/yubikey-5-overview/)
- [Backup Strategy](https://www.yubico.com/blog/backup-recovery-plan/)
- [TOTP Credentials Backup](https://docs.yubico.com/yesdk/users-manual/application-oath/oath-backup-credentials.html)

### TOTP Apps
- [2FAS](https://2fas.com/)
- [Aegis Authenticator](https://getaegis.app/)
- [Authy Desktop EOL](https://www.twilio.com/en-us/changelog/end-of-life--eol--of-twilio-authy-desktop-apps)
