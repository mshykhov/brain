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

### 2 пароля в голове = полное восстановление

| Пароль | Для чего |
|--------|----------|
| Keeper master | Вход в Keeper (там Gmail password) |
| Archive = Proton | Encrypted file + Proton |

С этими двумя паролями + recovery contact можно восстановить ВСЁ.

> Gmail password хранится в Keeper (защищён YubiKey).

### Hardware

```
2x YubiKey 5 NFC
├── Primary: с собой
└── Backup: дома

1x Ledger Nano X
└── Crypto self-custody

USB + Cloud:
├── 1x USB Archive (encrypted file) — когда купишь
└── Proton Drive (cloud backup)
```

### Recovery paths

**Worst case (потерял всё):**
```
Recovery contact → Gmail → Proton Drive → recovery.7z
                        → Расшифровать (Archive pwd)
                        → Keeper recovery phrase → Все пароли
```

**Keeper:** Master pwd + YubiKey → TOTP → Recovery phrase + Recovery codes

**Gmail:** Gmail pwd + YubiKey → Backup codes → Recovery email (Proton) → Recovery contact

**Proton:** Archive pwd + YubiKey → TOTP → Recovery codes → Recovery email (Gmail)
