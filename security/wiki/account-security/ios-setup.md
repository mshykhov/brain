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

### 2.1 Two-Factor Authentication

1. Settings → [Твоё имя] → **Sign-In & Security**
2. Two-Factor Authentication: **ON** (должно быть по умолчанию)

### 2.2 Добавить Security Keys (YubiKey)

> **Требования:** iOS 16.3+, минимум 2 Security Keys

1. Settings → [Твоё имя] → **Sign-In & Security**
2. **Security Keys** → **Add Security Keys**
3. Следуй инструкциям
4. Приложи **YubiKey #1** к верхней части iPhone (NFC)
5. Дождись подтверждения → дай имя: `YubiKey Primary`
6. **Повтори для YubiKey #2** → `YubiKey Backup`

> После добавления Security Keys, SMS-коды отключаются. Вход только через YubiKey.

### 2.3 Recovery Key (28 символов)

> **Важно:** Recovery Key позволяет восстановить Apple ID если потерял все устройства и YubiKeys.

1. Settings → [Твоё имя] → **Sign-In & Security**
2. **Account Recovery** → **Recovery Key**
3. Включи → введи passcode
4. **Запиши 28-символьный ключ** → сохрани в `recovery.txt`
5. Подтверди ключ (ввод)

```
Формат: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
Пример: A1B2-C3D4-E5F6-G7H8-I9J0-K1L2-M3N4
```

> **Храни отдельно от устройств!** Если потеряешь Recovery Key + все устройства + YubiKeys = потеря Apple ID навсегда.

### 2.4 Recovery Contacts (опционально)

Recovery Contact — доверенный человек который может помочь восстановить доступ.

1. Settings → [Твоё имя] → **Sign-In & Security**
2. **Account Recovery** → **Add Recovery Contact**
3. Выбери человека из контактов (у него должен быть Apple ID + iOS 15+)

> Recovery Contact НЕ получает доступ к твоим данным, только помогает подтвердить личность.

### 2.5 Trusted Devices

Список устройств которые могут получать коды подтверждения:

1. Settings → [Твоё имя] → **Devices**
2. Проверь список — удали неизвестные устройства

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

## Apple ID Recovery Paths

| # | Сценарий | Решение |
|---|----------|---------|
| 1 | Нормальный вход | Password + YubiKey |
| 2 | Потерял 1 YubiKey | Password + другой YubiKey |
| 3 | Потерял оба YubiKey | Recovery Key (28 символов) |
| 4 | Нет Recovery Key | Recovery Contact + ожидание |
| 5 | Забыл пароль + есть YubiKey | iforgot.apple.com + YubiKey |
| 6 | Забыл пароль + нет YubiKey | Recovery Key |
| 7 | Потерял ВСЁ | Recovery Contact (если настроен) |

> **Worst case:** Потерял все устройства + оба YubiKey + Recovery Key + нет Recovery Contact = **потеря Apple ID навсегда**.

### Что хранить в recovery.txt

```
=== APPLE ID ===
Email: myronshykhov@gmail.com (или iCloud)
Recovery Key: XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX
Recovery Contact: [имя человека]
```

---

## Чеклист

### Базовая защита
- [ ] Сильный passcode (6+ цифр или alphanumeric)
- [ ] Face ID настроен
- [ ] Apple ID 2FA включён

### Apple ID Security Keys
- [ ] YubiKey Primary добавлен
- [ ] YubiKey Backup добавлен
- [ ] Recovery Key записан и сохранён в recovery.txt
- [ ] Recovery Contact добавлен (опционально)

### YubiKey Apps
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
- [Apple: Recovery Key](https://support.apple.com/en-us/HT208072)
- [Apple: Recovery Contacts](https://support.apple.com/en-us/HT212513)
- [YubiKey iOS](https://www.yubico.com/works-with-yubikey/catalog/ios/)
