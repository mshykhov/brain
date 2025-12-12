# Crypto Security

Безопасное хранение криптовалют и работа с sensitive данными.

## Hardware Wallet

### Рекомендация: Ledger Nano X

| Характеристика | Значение |
|----------------|----------|
| Цена | ~$80-149 (смотри holiday sales) |
| Bluetooth | ✅ Да |
| iPhone | ✅ Да |
| Криптовалюты | 5,500+ |
| Чип безопасности | CC EAL5+ |

**Альтернатива:** Ledger Nano S Plus ($79) — если не нужен iPhone/Bluetooth.

### Зачем нужен hardware wallet

```
Без hardware wallet (биржа):
├── Биржа хранит твои ключи
├── Биржа банкротится → теряешь всё (FTX: $8 млрд)
├── Биржу взломали → теряешь всё
└── Аккаунт заблокирован → нет доступа

С hardware wallet:
├── Только ТЫ контролируешь ключи
├── Биржа банкротится → тебе пофиг
├── Никто не может заблокировать
└── "Not your keys, not your coins"
```

### Использование с DeFi

```
Ledger + Rabby/MetaMask:
├── Подключаешь Ledger к Rabby
├── Делаешь транзакцию (swap, stake, send)
├── На экране Ledger видишь детали
├── Подтверждаешь кнопкой
└── Ключ никогда не покидает устройство

Работает с:
├── DEX (Uniswap, Jupiter)
├── Liquidity pools
├── Staking
├── NFT
└── Любые DeFi протоколы
```

### Ledger Recover — НЕ использовать

```
❌ Ledger Recover ($9.99/месяц):
├── Seed отправляется 3 компаниям
├── Требует KYC (паспорт)
├── Ledger уже сливали данные (2020)
├── Правительство может запросить
└── Противоречит идее self-custody

✅ Твоя схема лучше:
├── Seed в encrypted file
├── Только ты знаешь пароль
├── Бесплатно
└── Никакого KYC
```

---

## Хранение Crypto Seeds

### Для сумм < $100k (путешественник)

```
Допустимо хранить в encrypted file:
├── Риск потери физического backup > риск взлома
├── < $100k не привлекает серьёзных хакеров
├── Атака требует: Gmail pwd + SIM swap + Archive pwd
└── Вероятность низкая
```

### Условия безопасного хранения

| Требование | Почему |
|------------|--------|
| Archive password уникальный | Не использовать нигде больше |
| Archive password сложный | 20+ символов |
| Hardware wallet | Для ежедневного использования |
| Tails OS для редактирования | Защита от malware |

### Passphrase (опционально)

```
Дополнительная защита:
├── Seed из файла → доступ к части средств (decoy)
├── Seed + passphrase в голове → основные средства
└── Даже если файл украдут — не всё потеряно
```

---

## Tails OS — безопасное редактирование

### Зачем нужен

```
Обычный компьютер при расшифровке:
├── Keylogger → записывает Archive password
├── Malware → копирует расшифрованный файл
├── Clipboard → перехватывает данные
├── RAM → данные остаются в памяти
└── Disk → временные файлы

Tails OS:
├── Загружается с USB
├── Работает только в RAM
├── После выключения — ВСЁ стирается
├── Offline режим
└── Никаких следов
```

### Как использовать

```
1. Выключи компьютер
2. Вставь USB с Tails
3. Загрузись с USB
4. Отключи интернет (Offline Mode)
5. Вставь USB с Archive
6. Расшифруй → редактируй → зашифруй
7. Выключи компьютер
8. RAM очищается, следов нет
```

### Установка Tails

1. Скачай с [tails.net](https://tails.net) (только официальный сайт!)
2. Запиши на USB (минимум 8GB)
3. Boot с USB → Disable Networking

---

## USB Flash Drives

### Рекомендуемые (водозащита)

| Модель | Водозащита | Скорость |
|--------|------------|----------|
| **Samsung FIT Plus** | 72ч в морской воде | 400MB/s |
| **Samsung BAR Plus** | Водо/удар/магнитоустойчивый | 400MB/s |
| SanDisk Ultra Trek | IP55 | 130MB/s |
| Corsair Survivor Stealth | 200м глубина | 150MB/s |

### Что нужно купить

| USB | Назначение | Размер |
|-----|------------|--------|
| #1 | Tails OS | 64-128GB |
| #2 | Tails OS backup | 64-128GB |
| #3 | Archive (encrypted file) | 32-64GB |
| #4 | Archive backup | 32-64GB |

### НЕ водостойкие (дешевле, но рискованнее)

- SanDisk Ultra Fit CZ430 — компактный, но БЕЗ водозащиты

---

## 7-Zip Best Practices

### Настройки шифрования

| Параметр | Значение |
|----------|----------|
| Формат | 7z |
| Encryption | **AES-256** |
| Encrypt file names | **ON** |
| Password | 20+ символов, уникальный |

### Важно

```
⚠️ При добавлении файла в архив — он НЕ шифруется автоматически!
   Нужно пересоздать архив полностью.
```

### Команды

**Создать:**
```bash
7z a -t7z -m0=lzma2 -mhe=on -p recovery.7z recovery.txt
```

**Распаковать:**
```bash
7z x recovery.7z
```

---

## Список покупок

| Что | Где | Цена |
|-----|-----|------|
| Ledger Nano X | shop.ledger.com | ~$80 (holiday sale) |
| YubiKey 5 NFC × 2 | yubico.com / Amazon | ~$55 × 2 |
| Samsung FIT/BAR Plus × 4 | Tokopedia / Lazada | ~$10-15 × 4 |

**Примерный бюджет:** ~$250-300

---

## Где покупать в Indonesia (без местного номера)

| Магазин | Способ оплаты |
|---------|---------------|
| Tokopedia | Gmail login + cash в Indomaret |
| Lazada | Visa/Mastercard |
| JakartaNotebook.com | Карта |
| Физические магазины | Наличные/карта |

---

## Источники

- [Ledger Official](https://shop.ledger.com)
- [Tails OS](https://tails.net)
- [Samsung FIT Plus Specs](https://www.samsung.com/us/computing/memory-storage/usb-flash-drives/)
- [7-Zip](https://www.7-zip.org)
