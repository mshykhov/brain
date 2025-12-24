# Gmail & Keeper Setup

Пошаговая настройка с 2x YubiKey 5 NFC.

## Перед началом

```
Нужно:
├── 2x YubiKey 5 NFC
├── Телефон с NFC
├── Компьютер
├── Доверенный человек с Google аккаунтом (для Recovery Contact)
└── 7-Zip установлен
```

## Порядок настройки

```
1. Gmail (создать, добавить YubiKeys, backup codes)
2. Proton (создать, TOTP сначала!, потом YubiKeys)
3. Gmail ← добавить Proton как recovery email
4. Keeper (TOTP сначала!, потом YubiKeys, recovery phrase + codes)
5. Encrypted file → Proton Drive
```

> **Важно:** В Proton и Keeper нужно сначала настроить TOTP, только потом Security Keys!

---

## Шаг 1: Gmail

### 1.1 Создать аккаунт

1. Открой [accounts.google.com/signup](https://accounts.google.com/signup)
2. Создай аккаунт (формат: `myronshykhov@gmail.com`)
3. Пароль — сохрани в Keeper (потом)

### 1.2 Recovery options

1. [myaccount.google.com](https://myaccount.google.com) → Security
2. Recovery phone → **свой номер**
3. Recovery contact → **доверенный человек** (родственник/друг)
   - Добавь на [g.co/recovery-contacts](https://g.co/recovery-contacts)
   - Можно до 10 контактов
   - 7 дней ожидания после добавления

> Recovery email (Proton) добавим позже.

### 1.3 Добавить YubiKey (FIDO2)

1. Security → 2-Step Verification → включи
2. Passkeys and security keys → Add security key
3. Вставь YubiKey #1 → нажми кнопку на ключе
4. Дай имя: `YubiKey Primary`
5. **Повтори для YubiKey #2** → `YubiKey Backup`

### 1.4 Backup codes

1. Security → 2-Step Verification
2. Backup codes → Get backup codes
3. **Скопируй все 10 кодов** — сохрани временно в Notepad

---

## Шаг 2: Proton Mail

### 2.1 Создать аккаунт

1. Открой [proton.me](https://proton.me)
2. Sign up → бесплатный план ОК
3. **Пароль = Archive password** (один из 2 паролей в голове!)

### 2.2 Recovery options

> **Важно:** Настрой recovery ДО включения 2FA.

1. Settings → Account → Recovery
2. Recovery email → добавь **Gmail**
3. Recovery phone → **свой номер** (может не работать — ОК)
4. Скачай **Recovery file**

### 2.3 Добавить TOTP (сначала!)

> **Важно:** В Proton нужно сначала TOTP, потом Security Keys.

1. Settings → Security → Two-factor authentication
2. **Authenticator app** → включи
3. **СТОП!** Сначала сохрани seed:
   - Нажми "Can't scan?" или покажи код вручную
   - Скопируй secret key → **сохрани в Notepad**
4. Введи 6-значный код → подтверди

### 2.4 Добавить YubiKey (FIDO2)

1. Settings → Security → Two-factor authentication
2. **Security keys** → Add security key
3. Вставь YubiKey #1 → нажми кнопку
4. Дай имя: `YubiKey Primary`
5. **Повтори для YubiKey #2** → `YubiKey Backup`

### 2.5 Recovery codes

1. Settings → Security → Recovery codes
2. **Скопируй все коды** → сохрани в Notepad

---

## Шаг 3: Gmail ← Proton recovery

1. [myaccount.google.com](https://myaccount.google.com) → Security
2. Recovery email → добавь **Proton Mail**
3. Подтверди через код на Proton

---

## Шаг 4: Keeper

### 4.1 Добавить TOTP (сначала!)

> **Важно:** В Keeper нужно сначала TOTP, потом Security Keys. TOTP также служит backup методом.

1. Keeper Web Vault → Settings → Security
2. Two-Factor Authentication → Edit
3. **Authenticator app** → включи
4. **СТОП!** Сначала сохрани seed:
   - Покажи QR код → нажми "Can't scan?" или "Enter key manually"
   - Скопируй secret key → **сохрани в Notepad**
5. Введи 6-значный код → подтверди

### 4.2 Добавить YubiKey (FIDO2)

1. Settings → Security → Two-Factor Authentication
2. **Security Key** → Add
3. Вставь YubiKey #1 → нажми кнопку
4. Дай имя: `YubiKey Primary`
5. **Повтори для YubiKey #2** → `YubiKey Backup`

### 4.3 Recovery Phrase

1. Settings → Recovery Phrase
2. Generate Recovery Phrase
3. **Скопируй 24 слова в Notepad**

> Recovery phrase позволяет сбросить master password, но всё равно потребуется пройти 2FA.

### 4.4 Recovery Codes

1. Settings → Security → Two-Factor Authentication
2. Recovery Codes → View/Generate
3. **Скопируй все 8 кодов в Notepad**

> Recovery codes — одноразовые коды для входа если нет YubiKey и TOTP.

### 4.5 Настройки безопасности

1. Settings → Security:
   - Logout Timer: **15 минут**
   - Device Approval: **ON**
2. На телефоне: включи Biometrics

---

## Шаг 5: Encrypted File

### 5.1 Содержимое recovery.txt

```
=== KEEPER ===
Recovery Phrase:
word1 word2 word3 word4 word5 word6
word7 word8 word9 word10 word11 word12
word13 word14 word15 word16 word17 word18
word19 word20 word21 word22 word23 word24

TOTP Secret: XXXXXXXXXXXXXXXX

Recovery Codes:
XXXXXXXX
XXXXXXXX
[остальные 6 кодов]

=== GMAIL ===
Backup Codes:
12345678
23456789
[остальные 8 кодов]

Recovery phone: +XXX XXX XXX (мой)
Recovery contact: [имя доверенного человека]

=== PROTON ===
Email: твой@proton.me
TOTP Secret: XXXXXXXXXXXXXXXX
Password: = Archive password

Recovery Codes:
XXXXXX
XXXXXX
[остальные коды]

=== YUBIKEY ===
Primary: с собой
Backup: дома
```

### 5.2 Зашифровать

**Windows (7-Zip):**
```
Правый клик на recovery.txt → 7-Zip → Add to archive
├── Archive format: 7z
├── Encryption method: AES-256
├── Encrypt file names: ✅
└── Password: Archive password
```

**Linux/macOS:**
```bash
7z a -t7z -m0=lzma2 -mhe=on -p recovery.7z recovery.txt
```

### 5.3 Удалить оригинал

**Windows:**
```
Shift + Delete (не в корзину)
```

**Linux:**
```bash
shred -u recovery.txt
```

### 5.4 Сохранить копии

1. Копия на USB (дома)
2. Копия на Proton Drive

---

## Шаг 6: Проверка

### Проверь YubiKey Primary

- [ ] Gmail логин работает с YubiKey (FIDO2)
- [ ] Keeper логин работает с YubiKey (FIDO2)
- [ ] Proton логин работает с YubiKey (FIDO2)

### Проверь YubiKey Backup

- [ ] Повтори все проверки с backup ключом

### Проверь TOTP backup

- [ ] Keeper TOTP работает (из Yubico Authenticator)
- [ ] Proton TOTP работает (из Yubico Authenticator)

### Проверь Encrypted File

- [ ] Расшифруй файл с Proton Drive
- [ ] Проверь что все данные читаемы
- [ ] (Потом) Расшифруй копию с USB

### Проверь Recovery Contact

- [ ] Убедись что доверенный человек принял invite
- [ ] Прошло 7 дней с момента добавления

---

## Recovery Paths

### Keeper

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Master pwd + YubiKey |
| 2 | Потерял 1 YubiKey | Master pwd + другой YubiKey |
| 3 | Потерял оба YubiKey | Master pwd + TOTP (из Yubico Authenticator или USB) |
| 4 | Нет TOTP | Master pwd + Recovery codes (USB или Proton Drive) |
| 5 | Забыл Master pwd | Recovery phrase + 2FA |
| 6 | Потерял YubiKeys + нет backup 2FA | Контакт Keeper Support (сброс 2FA) |
| 7 | Залогинен на устройстве | Biometrics → Settings → Reset Master Password |

### Gmail

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Gmail pwd + YubiKey |
| 2 | Потерял YubiKeys | Gmail pwd + Backup codes (Archive pwd → USB) |
| 3 | Нет backup codes | Gmail pwd + Recovery email (Proton) |
| 4 | Нет доступа к Proton | Gmail pwd + Recovery phone |
| 5 | Потерял свой телефон | Gmail pwd + Recovery contact (доверенный) |

### Proton

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Archive pwd + YubiKey (FIDO2) |
| 2 | Потерял 1 YubiKey | Archive pwd + другой YubiKey |
| 3 | Потерял оба YubiKey | Archive pwd + TOTP (Yubico Authenticator или USB) |
| 4 | Нет TOTP | Archive pwd + Recovery codes (USB или Proton Drive) |
| 5 | Забыл Archive pwd | Recovery email (Gmail) |

> **Примечание:** При восстановлении через email данные остаются зашифрованными. Нужен Archive pwd для расшифровки.

---

## Независимость путей

```
Recovery Contact (доверенный) ──────────────────┐
                                                │
Recovery Phone (свой) ──────────────────────────┤
       │                                        │
       ▼                                        │
    Gmail ◄─────────────────────────────────────┤
       │                                        │
       ▼                                        │
   Proton Drive → recovery.7z                   │
       │                                        │
       ▼ (Archive pwd)                          │
   Keeper recovery phrase → Master pwd reset    │
       │                                        │
       ▼                                        │
   Все пароли восстановлены                     │
       │                                        │
       └─────── Recovery email (Gmail) ─────────┘

Независимые точки входа:
1. YubiKey (любой из двух)
2. Archive password + USB/Proton Drive
3. Recovery phone + Gmail password
4. Recovery contact + Gmail password (если потерял телефон)
```

---

## Важно помнить

### 2 пароля в голове

| Пароль | Для чего |
|--------|----------|
| Keeper master | Вход в Keeper (там Gmail password) |
| Archive = Proton | Encrypted file + Proton |

> Gmail password хранится в Keeper (защищён YubiKey).

### Что защищает YubiKey

✅ Защищает от:
- Фишинг (FIDO2 привязан к домену)
- Удалённый перехват паролей
- SIM swap атаки

❌ НЕ защищает от:
- Keylogger на твоём PC
- Malware с полным доступом
- Физический доступ к разблокированному устройству

### Keeper Support

Если потерял все 2FA методы, Keeper Support может сбросить 2FA для индивидуальных пользователей. Потребуется подтверждение личности.

### Recovery Contact (доверенный человек)

Recovery contact — человек с Google аккаунтом, который может помочь восстановить доступ:
- Получает запрос на верификацию (number matching)
- Должен ответить в течение 15 минут
- **НЕ получает доступ** к твоему аккаунту или данным
- Можно добавить до 10 контактов
- 7 дней ожидания после добавления

Добавить: [g.co/recovery-contacts](https://g.co/recovery-contacts)

---

## Источники

- [Keeper: Two-Factor Authentication](https://docs.keeper.io/en/enterprise-guide/two-factor-authentication)
- [Keeper: Recovery Phrase](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
- [Google: Security Key](https://support.google.com/accounts/answer/6103523)
- [Google: Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Proton: Lost 2FA Device](https://proton.me/support/lost-two-factor-authentication-2fa)
- [Proton: Reset Password](https://proton.me/support/reset-password)
