# Gmail & Keeper Setup

Пошаговая настройка с 2x YubiKey 5 NFC.

## Перед началом

```
Нужно:
├── 2x YubiKey 5 NFC
├── Телефон с NFC
├── Компьютер
└── Proton Mail аккаунт (или создать)
```

---

## Шаг 1: Proton Mail

### 1.1 Создать аккаунт

1. Открой [proton.me](https://proton.me)
2. Sign up → бесплатный план достаточно
3. **Пароль = Archive password** (запомни!)

### 1.2 Включить 2FA

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

---

## Шаг 2: Gmail

### 2.1 Recovery options

1. [myaccount.google.com](https://myaccount.google.com) → Security
2. Recovery email → добавь Proton Mail
3. Recovery phone → добавь номер

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

---

## Шаг 3: Keeper

### 3.1 Добавить YubiKey

1. Keeper Web Vault → Settings → Security
2. Two-Factor Authentication → Edit
3. Security Key → Add
4. Вставь YubiKey #1 → нажми кнопку
5. **Повтори для YubiKey #2**

### 3.2 Recovery Phrase

1. Settings → Recovery Phrase
2. Generate Recovery Phrase
3. **Скопируй 24 слова в `recovery.txt`**

### 3.3 Настройки безопасности

1. Settings → Security:
   - Logout Timer: **15 минут**
   - Device Approval: **ON**
2. На телефоне: включи Biometrics

---

## Шаг 4: Encrypted File

### 4.1 Содержимое recovery.txt

```
=== KEEPER ===
Recovery Phrase:
word1 word2 word3 word4 word5 word6
word7 word8 word9 word10 word11 word12
word13 word14 word15 word16 word17 word18
word19 word20 word21 word22 word23 word24

=== GMAIL ===
Backup Codes:
12345678
23456789
[остальные 8 кодов]

=== PROTON ===
Email: твой@proton.me
TOTP Secret: XXXXXXXXXXXXXXXX
Password: = Archive password

=== YUBIKEY ===
Primary: с собой
Backup: дома
```

### 4.2 Зашифровать

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

### 4.3 Удалить оригинал

**Windows:**
```
Shift + Delete (не в корзину)
```

**Linux:**
```bash
shred -u recovery.txt
```

### 4.4 Сохранить копии

1. Копия на USB (дома)
2. Копия на Proton Drive

---

## Шаг 5: Проверка

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

---

## Recovery Paths

### Keeper (3 пути)

| # | Путь | Что нужно |
|---|------|-----------|
| 1 | Normal | Master pwd + YubiKey |
| 2 | Recovery | Archive pwd → phrase |
| 3 | Biometrics | Телефон |

### Gmail (4 пути)

| # | Путь | Что нужно |
|---|------|-----------|
| 1 | Normal | Gmail pwd + YubiKey |
| 2 | Backup codes | Gmail pwd + Archive pwd |
| 3 | Recovery email | Proton (Archive pwd) |
| 4 | Recovery phone | SIM |

---

## Источники

- [Google: Security Key](https://support.google.com/accounts/answer/6103523)
- [Google: Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Keeper: Security Key](https://docs.keeper.io/en/enterprise-guide/two-factor-authentication)
- [Keeper: Recovery Phrase](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
