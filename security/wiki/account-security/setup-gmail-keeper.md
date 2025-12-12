# Gmail & Keeper Setup

Пошаговая настройка с 2x YubiKey 5 NFC.

## Перед началом

```
Нужно:
├── 2x YubiKey 5 NFC
├── Телефон с NFC
├── Компьютер
├── Второй номер телефона (родственник/друг)
└── Proton Mail аккаунт (или создать)
```

---

## Шаг 1: Proton Mail

### 1.1 Создать аккаунт

1. Открой [proton.me](https://proton.me)
2. Sign up → бесплатный план достаточно
3. **Пароль = Archive password** (запомни!)

### 1.2 Recovery options

> **Важно:** Настрой recovery ДО включения 2FA.

1. Settings → Account → Recovery
2. Recovery email → добавь **Gmail**
3. Recovery phone → добавь **свой номер**

### 1.3 Включить 2FA

1. Settings → Security → Two-factor authentication
2. Покажется QR код
3. **СТОП!** Сначала сохрани seed:
   - Нажми "Can't scan QR code?" или "Enter key manually"
   - Скопируй secret key
   - Сохрани в файл `recovery.txt`
4. Теперь добавь в YubiKey #1:
   - Открой Yubico Authenticator
   - Add account → Manual → вставь secret
5. Повтори для YubiKey #2
6. Введи код → Confirm

### 1.4 Recovery codes

1. После включения 2FA → покажутся recovery codes
2. **Скопируй все коды в `recovery.txt`**

> Каждый код одноразовый. Используется вместо TOTP если потерял YubiKey.

---

## Шаг 2: Gmail

### 2.1 Recovery options

1. [myaccount.google.com](https://myaccount.google.com) → Security
2. Recovery email → добавь **Proton Mail**
3. Recovery phone #1 → **свой номер**
4. Recovery phone #2 → **номер доверенного человека** (родственник)

> Второй номер — независимый путь восстановления если потеряешь свой телефон.

### 2.2 Добавить YubiKey (FIDO2)

1. Security → 2-Step Verification → Get started
2. Passkeys and security keys → Add security key
3. Вставь YubiKey #1 → нажми кнопку на ключе
4. Дай имя: "YubiKey Primary"
5. **Повтори для YubiKey #2** → "YubiKey Backup"

### 2.3 Backup codes

1. Security → 2-Step Verification
2. Backup codes → Get backup codes
3. **Скопируй все 10 кодов в `recovery.txt`**

> После использования код становится неактивным. Можно сгенерировать новые 10 кодов в любое время.

---

## Шаг 3: Keeper

### 3.1 Добавить YubiKey

1. Keeper Web Vault → Settings → Security
2. Two-Factor Authentication → Edit
3. Security Key → Add
4. Вставь YubiKey #1 → нажми кнопку
5. **Повтори для YubiKey #2**

### 3.2 Добавить Backup 2FA (TOTP)

> **Важно:** Keeper требует backup 2FA метод при использовании Security Keys. Рекомендуется TOTP вместо SMS (защита от SIM swap атак).

1. Settings → Security → Two-Factor Authentication
2. Включи Google/Microsoft Authenticator (TOTP)
3. **Сохрани TOTP seed в `recovery.txt`**
4. Добавь в YubiKey (опционально) или любой authenticator

### 3.3 Recovery Phrase

1. Settings → Recovery Phrase
2. Generate Recovery Phrase
3. **Скопируй 24 слова в `recovery.txt`**

> Recovery phrase позволяет сбросить master password, но всё равно потребуется пройти 2FA.

### 3.4 Настройки безопасности

1. Settings → Security:
   - Logout Timer: **15 минут**
   - Device Approval: **ON**
2. На телефоне: включи Biometrics

---

## Шаг 4: Gmail Failsafe

> **Цель:** Если потеряешь всё кроме доступа к recovery phone, сможешь восстановить через Gmail.

### 4.1 Сохрани в Google Keep или Gmail Draft

1. Открой [keep.google.com](https://keep.google.com) или создай Draft в Gmail
2. Добавь:
   - Keeper TOTP seed
   - Proton TOTP seed
   - Proton recovery codes

**Это позволит:**
- Войти в Gmail через recovery phone (свой или доверенного человека)
- Получить TOTP seeds и recovery codes из Gmail
- Восстановить Keeper и Proton

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

=== GMAIL ===
Backup Codes:
12345678
23456789
[остальные 8 кодов]

Recovery phones:
1. +XXX XXX XXX (мой)
2. +XXX XXX XXX (доверенный)

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

- [ ] Gmail логин работает с YubiKey
- [ ] Keeper логин работает с YubiKey
- [ ] Proton TOTP с YubiKey работает

### Проверь YubiKey Backup

- [ ] Повтори все проверки с backup ключом

### Проверь Encrypted File

- [ ] Расшифруй файл с USB
- [ ] Проверь что все данные читаемы
- [ ] Расшифруй копию с Proton Drive

### Проверь Gmail Failsafe

- [ ] TOTP seeds доступны в Google Keep/Draft
- [ ] Proton recovery codes доступны

### Проверь второй recovery phone

- [ ] Попроси доверенного человека подтвердить что номер работает

---

## Recovery Paths

### Keeper

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Master pwd + YubiKey |
| 2 | Потерял 1 YubiKey | Master pwd + другой YubiKey |
| 3 | Потерял оба YubiKey | Master pwd + TOTP (из Gmail или USB) |
| 4 | Забыл Master pwd | Recovery phrase + 2FA |
| 5 | Потерял телефон + YubiKeys | Gmail (2й recovery phone) → TOTP seed → Keeper |
| 6 | Потерял YubiKeys + нет backup 2FA | Контакт Keeper Support (сброс 2FA) |
| 7 | Залогинен на устройстве | Biometrics → Settings → Reset Master Password |

### Gmail

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Gmail pwd + YubiKey |
| 2 | Потерял YubiKeys | Gmail pwd + Backup codes (Archive pwd → USB) |
| 3 | Нет backup codes | Gmail pwd + Recovery email (Proton) |
| 4 | Нет доступа к Proton | Gmail pwd + Recovery phone #1 |
| 5 | Потерял свой телефон | Gmail pwd + Recovery phone #2 (доверенный) |

### Proton

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Archive pwd + TOTP (YubiKey) |
| 2 | Потерял YubiKeys | Archive pwd + TOTP seed (USB или Gmail) |
| 3 | Нет TOTP seed | Archive pwd + Recovery codes (USB или Gmail) |
| 4 | Забыл Archive pwd | Recovery email (Gmail) или Recovery phone |

> **Примечание:** При восстановлении через email/phone данные остаются зашифрованными. Нужен Archive pwd для расшифровки.

---

## Независимость путей

```
Recovery Phone #2 (доверенный) ─────────────────┐
                                                │
Recovery Phone #1 (свой) ───────────────────────┤
       │                                        │
       ▼                                        │
    Gmail ◄────────────────────────┐            │
       │                           │            │
       │  ┌── TOTP seeds ─────────►│            │
       │  │   Proton codes         │            │
       │  │   (Google Keep)        │            │
       ▼  │                        │            │
   Keeper ◄───── Master pwd ───────┤            │
       │                           │            │
       ▼                           │            │
   Proton ◄───── Archive pwd ──────┘            │
       │                                        │
       └─────── Recovery email (Gmail) ─────────┘

Независимые точки входа:
1. YubiKey (любой из двух)
2. Archive password + USB
3. Recovery phone #1 + Gmail password
4. Recovery phone #2 + Gmail password (если потерял свой телефон)
```

---

## Важно помнить

### 3 пароля в голове

| Пароль | Для чего |
|--------|----------|
| Gmail | Вход в Gmail |
| Keeper master | Вход в Keeper |
| Archive = Proton | Encrypted file + Proton |

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

### Доверенный человек

Второй recovery phone должен быть у человека которому доверяешь. Он сможет получить SMS код для входа в твой Gmail, но:
- Не знает твой Gmail пароль
- Не имеет доступа к твоим данным
- Только помогает восстановить доступ в экстренной ситуации

---

## Источники

- [Keeper: Two-Factor Authentication](https://docs.keeper.io/en/enterprise-guide/two-factor-authentication)
- [Keeper: Recovery Phrase](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
- [Google: Security Key](https://support.google.com/accounts/answer/6103523)
- [Google: Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Proton: Lost 2FA Device](https://proton.me/support/lost-two-factor-authentication-2fa)
- [Proton: Reset Password](https://proton.me/support/reset-password)
