# Windows Setup

Настройки безопасности Windows 10/11.

## 1. Windows Security

Открой: **Settings → Privacy & security → Windows Security**

### Virus & threat protection

- [ ] Real-time protection: **ON**
- [ ] Cloud-delivered protection: **ON**
- [ ] Automatic sample submission: **ON**
- [ ] Tamper Protection: **ON**

### Device security

- [ ] Core isolation → Memory integrity: **ON**
- [ ] Secure Boot: **ON** (проверь в BIOS если выключено)

### App & browser control

- [ ] Smart App Control: **ON** (или Reputation-based protection)
- [ ] Check apps and files: **Warn**
- [ ] SmartScreen for Edge: **Warn**
- [ ] Phishing protection: **ON**

---

## 2. Стандартный пользователь

**Почему:** Admin = malware получает полный доступ

### Создать стандартный аккаунт

1. Settings → Accounts → Other users
2. Add account → создай новый
3. Change account type → **Standard User**
4. Используй этот аккаунт для ежедневной работы
5. Admin только для установки софта

---

## 3. Windows Hello PIN

**Почему:** PIN привязан к устройству, бесполезен на другом PC

1. Settings → Accounts → Sign-in options
2. PIN (Windows Hello) → Add
3. Создай PIN (минимум 6 цифр, лучше больше)

---

## 4. Chrome

### Настройки

1. chrome://settings/security:
   - Safe Browsing: **Enhanced protection**
   - Always use secure connections: **ON**
   - Use secure DNS: **ON**

2. chrome://settings/passwords:
   - Offer to save passwords: **OFF**
   - Auto Sign-in: **OFF**

### Device Bound Session Credentials

1. Открой chrome://flags
2. Найди "Device Bound Session Credentials"
3. Включи → Restart Chrome

---

## 5. Keeper

1. Установи [Keeper Desktop](https://keepersecurity.com/download.html)
2. Установи [Keeper Browser Extension](https://chrome.google.com/webstore/detail/keeper)
3. Settings → Security:
   - Logout Timer: **15 минут**

---

## 6. YubiKey

### Софт

1. Установи [Yubico Authenticator](https://www.yubico.com/products/yubico-authenticator/)
   - Для TOTP кодов с YubiKey

### Использование

```
FIDO2 (Gmail, Keeper):
→ Вставь YubiKey → нажми кнопку

TOTP (Proton):
→ Открой Yubico Authenticator
→ Вставь или приложи YubiKey (NFC)
→ Скопируй код
```

---

## Чеклист

### Windows Security
- [ ] Real-time protection ON
- [ ] Memory integrity ON
- [ ] SmartScreen ON

### Аккаунт
- [ ] Работаю под стандартным юзером
- [ ] Windows Hello PIN настроен

### Chrome
- [ ] Enhanced Safe Browsing
- [ ] Password manager отключен
- [ ] DBSC включен (flags)

### Apps
- [ ] Keeper Desktop установлен
- [ ] Keeper Extension установлен
- [ ] Yubico Authenticator установлен

---

## Источники

- [Windows Security](https://support.microsoft.com/en-us/windows/stay-protected-with-windows-security)
- [Memory Integrity](https://support.microsoft.com/en-us/windows/core-isolation)
