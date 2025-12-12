# Account Security

> **Обновлено:** Декабрь 2024

## Setup Guides

| Doc | Описание |
|-----|----------|
| [Gmail & Keeper Setup](setup-gmail-keeper.md) | Настройка с 2x YubiKey |
| [Windows Setup](windows-setup.md) | Защита Windows |
| [iOS Setup](ios-setup.md) | Защита iPhone |
| [Linux Setup](linux-setup.md) | Защита Linux |

## Quick Reference

### 3 пароля в голове

| Пароль | Для чего |
|--------|----------|
| Gmail | Вход в Gmail |
| Keeper master | Вход в Keeper |
| Archive = Proton | Encrypted file + Proton |

### Hardware

```
2x YubiKey 5 NFC
├── Primary: с собой
└── Backup: дома
```

### Recovery paths

**Keeper:** Master pwd + YubiKey → Recovery phrase → Biometrics

**Gmail:** Gmail pwd + YubiKey → Backup codes → Recovery email → Recovery phone
