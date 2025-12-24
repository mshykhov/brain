# Account Security

> **Обновлено:** Декабрь 2024

## Setup Guides

| Doc | Описание |
|-----|----------|
| [Gmail & Keeper Setup](setup-gmail-keeper.md) | Настройка с 2x YubiKey |
| [Crypto Security](crypto-security.md) | Ledger, Tails OS, seeds |
| [Windows Setup](windows-setup.md) | Защита Windows |
| [iOS Setup](ios-setup.md) | Защита iPhone |
| [Linux Setup](linux-setup.md) | Защита Linux |

## Quick Reference

### 2 пароля = полное восстановление

| Пароль | Для чего |
|--------|----------|
| Gmail | Вход в Gmail + recovery phone |
| Archive = Proton | Encrypted file + Proton |

С этими двумя паролями + recovery contact можно восстановить ВСЁ.

### Hardware

```
2x YubiKey 5 NFC
├── Primary: с собой
└── Backup: дома

1x Ledger Nano X
└── Crypto self-custody

4x USB (водостойкие)
├── 2x Tails OS (система + backup)
└── 2x Archive (encrypted file + backup)
```

### Recovery paths

**Worst case (потерял всё):**
```
Recovery contact → Gmail → Google Keep (TOTP seeds)
                        → Proton Drive → Encrypted file
                        → Keeper → Все пароли
```

**Keeper:** Master pwd + YubiKey → TOTP → Recovery phrase

**Gmail:** Gmail pwd + YubiKey → Backup codes → Recovery email → Recovery phone/contact

**Proton:** Archive pwd + YubiKey → TOTP → Recovery codes → Recovery email/phone
