# Account Security

Полная система защиты и восстановления критических аккаунтов.

> **Последнее обновление:** Декабрь 2024

## TL;DR

```
3 пароля в голове
2 YubiKey (primary + backup)
1 USB + 1 Cloud
= 3+ независимых пути восстановления
```

## Документы

| Файл | Описание |
|------|----------|
| [Recovery Architecture](recovery-architecture.md) | Пути восстановления Keeper и Gmail |
| [YubiKey Setup](yubikey-setup.md) | Настройка и использование YubiKey |
| [Keeper Settings](keeper-settings.md) | Настройки безопасности Keeper |
| [Windows Hardening](windows-hardening.md) | Защита Windows от malware |
| [Browser Security](browser-security.md) | Настройки Chrome |
| [Threat Model](threat-model.md) | Что защищает YubiKey, а что нет |

## Quick Reference

### 3 пароля в голове

| # | Пароль | Для чего |
|---|--------|----------|
| 1 | Gmail | Вход в Gmail |
| 2 | Keeper master | Вход в Keeper |
| 3 | Archive = Proton | Encrypted file + Proton |

### Независимые пути восстановления

**Keeper:** Master pwd + YubiKey → Recovery phrase → Biometrics

**Gmail:** Gmail pwd + YubiKey → Backup codes → Recovery email → Recovery phone
