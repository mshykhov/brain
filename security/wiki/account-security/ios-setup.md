# iOS Setup

Настройки безопасности iPhone/iPad.

## 1. Passcode & Face ID

### Сильный passcode

1. Settings → Face ID & Passcode
2. Change Passcode → Passcode Options
3. Выбери **Custom Alphanumeric Code** (самый надёжный)
   - Или минимум 6 цифр

### Face ID

1. Settings → Face ID & Passcode
2. Set Up Face ID
3. Включи для:
   - [ ] iPhone Unlock
   - [ ] Wallet & Apple Pay
   - [ ] Password AutoFill
   - [ ] Other Apps (Keeper)

---

## 2. Apple ID Security

1. Settings → [Твоё имя] → Sign-In & Security
2. Two-Factor Authentication: **ON** (должно быть по умолчанию)
3. Security Keys → Add Security Key:
   - Добавь YubiKey #1 (через NFC)
   - Добавь YubiKey #2

---

## 3. Keeper

### Установка

1. App Store → Keeper Password Manager
2. Войди с master password + YubiKey

### Настройки

1. Settings → Security:
   - Biometric Login: **ON**
   - Auto-Lock: **1-5 минут**
   - Logout Timer: **15 минут**

### Face ID

1. Settings → Face ID & Passcode
2. Other Apps → Keeper: **ON**

---

## 4. YubiKey на iPhone

### Как использовать

```
FIDO2 (Gmail, Keeper в Safari):
1. При запросе 2FA
2. Приложи YubiKey к верхней части iPhone (NFC)
3. Держи пока не появится галочка

TOTP (Proton):
1. Установи Yubico Authenticator из App Store
2. Открой app → приложи YubiKey
3. Скопируй код
```

### Совместимость

| iPhone | NFC | USB-C |
|--------|-----|-------|
| iPhone 7+ | ✅ | ❌ |
| iPhone 15+ | ✅ | ✅ |

---

## 5. Safari

### Настройки

1. Settings → Safari → Advanced
2. Fraudulent Website Warning: **ON**

### Passwords

1. Settings → Passwords
2. AutoFill Passwords: можно оставить **OFF** (используй Keeper)
   - Или включить только для Keeper

---

## 6. Privacy

### App Tracking

1. Settings → Privacy & Security
2. Tracking → Allow Apps to Request to Track: **OFF**

### Location

1. Settings → Privacy & Security → Location Services
2. Проверь каждое app, удали ненужные разрешения

---

## Чеклист

### Базовая защита
- [ ] Сильный passcode (6+ цифр или alphanumeric)
- [ ] Face ID настроен
- [ ] Apple ID 2FA включён

### YubiKey
- [ ] YubiKey добавлен в Apple ID (опционально)
- [ ] Yubico Authenticator установлен

### Keeper
- [ ] Keeper установлен
- [ ] Face ID для Keeper включён
- [ ] Auto-Lock: 1-5 минут

### Privacy
- [ ] App Tracking отключен
- [ ] Location permissions проверены

---

## Источники

- [Apple: Security Keys](https://support.apple.com/en-us/HT213154)
- [Apple: Two-Factor Authentication](https://support.apple.com/en-us/HT204915)
- [YubiKey iOS](https://www.yubico.com/works-with-yubikey/catalog/ios/)
