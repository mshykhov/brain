# Recovery Architecture

3+ независимых пути восстановления для каждого сервиса.

## Keeper: 3 пути

| # | Путь | Что нужно |
|---|------|-----------|
| 1 | Нормальный вход | Master pwd + YubiKey |
| 2 | Recovery phrase | Archive pwd + USB/Cloud |
| 3 | Biometrics | Телефон с Keeper |

## Gmail: 4 пути

| # | Путь | Что нужно |
|---|------|-----------|
| 1 | Нормальный вход | Gmail pwd + YubiKey |
| 2 | Backup codes | Gmail pwd + Archive pwd |
| 3 | Recovery email | Archive pwd (Proton) |
| 4 | Recovery phone | SIM карта |

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
│   FIDO2 + TOTP seeds        │   FIDO2 + TOTP seeds          │
└─────────────────────────────┴───────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    1 USB + 1 CLOUD                          │
├─────────────────────────────┬───────────────────────────────┤
│   USB (дома)                │   Proton Drive + Mail         │
│   encrypted file            │   encrypted file              │
│   (Archive pwd)             │   (Archive pwd)               │
└─────────────────────────────┴───────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              НЕЗАВИСИМЫЕ ПУТИ (без паролей!)                │
├─────────────────────────────┬───────────────────────────────┤
│   Recovery phone            │   Keeper biometrics           │
│   (нужна только SIM)        │   (нужен только телефон)      │
└─────────────────────────────┴───────────────────────────────┘
```

## Матрица независимости

### Keeper

| Потерял | Path 1 | Path 2 | Path 3 | OK? |
|---------|--------|--------|--------|-----|
| Master pwd | ❌ | ✅ | ✅ | ✅ |
| Оба YubiKey | ✅ | ✅ | ✅ | ✅ |
| Archive pwd | ✅ | ❌ | ✅ | ✅ |
| Телефон | ✅ | ✅ | ❌ | ✅ |

### Gmail

| Потерял | Path 1 | Path 2 | Path 3 | Path 4 | OK? |
|---------|--------|--------|--------|--------|-----|
| Gmail pwd | ❌ | ❌ | ✅ | ✅ | ✅ |
| Archive pwd | ✅ | ❌ | ❌ | ✅ | ✅ |
| Телефон+SIM | ✅ | ✅ | ✅ | ❌ | ✅ |

## Сценарии восстановления

### Забыл Keeper master password

```
A) Есть телефон → Biometrics → Reset Master Password
B) Нет телефона → Encrypted file → Recovery phrase → Forgot Password
```

### Забыл Gmail password

```
A) Recovery phone → код → новый пароль
B) Recovery email (Proton) → код → новый пароль
C) Backup codes из encrypted file
```

### Потерял телефон

```
1. Backup YubiKey дома → использовать его
2. Нет YubiKey → backup codes / recovery phrase из encrypted file
3. Новый телефон → восстановить TOTP из seeds
```

### Забыл Archive password (WORST CASE)

```
1. Gmail: recovery phone работает → OK
2. Keeper: biometrics работает → OK
3. После входа → создать НОВЫЙ encrypted file
```

## Encrypted File содержимое

```
recovery.7z (Archive pwd):

=== KEEPER ===
Recovery Phrase: word1 word2 ... word24

=== GMAIL ===
Backup Codes:
12345678 (x10)

=== TOTP SEEDS ===
otpauth://totp/Proton?secret=XXX&issuer=Proton

=== PROTON ===
Email: user@proton.me
Password: = Archive password
```

## Создание encrypted file

```bash
# Создать
7z a -t7z -m0=lzma2 -mx=9 -mhe=on -p recovery.7z recovery.txt

# Удалить оригинал
shred -u recovery.txt  # Linux/macOS
```

## Источники

- [Keeper: Master Password Reset](https://docs.keeper.io/en/user-guides/troubleshooting/reset-your-master-password)
- [Google: Backup Codes](https://support.google.com/accounts/answer/1187538)
- [Google: Account Recovery](https://support.google.com/accounts/answer/7682439)
