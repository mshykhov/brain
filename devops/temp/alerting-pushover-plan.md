# Alerting + Pushover Integration Plan

## Цель

Критические алерты должны приходить через iOS Critical Alerts (Pushover) - обходят DND.

## Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                    CRITICAL PATH                             │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Prometheus → AlertManager ─┬→ Telegram (все алерты)        │
│                             └→ Pushover (critical only)     │
│                                                              │
│  Services → Healthchecks.io → Pushover (dead man's switch)  │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    NON-CRITICAL                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Telegram Bot (notifier) → Pushover (user subscriptions)    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Компоненты

### 1. AlertManager → Pushover (native)

AlertManager имеет нативную поддержку Pushover.

Docs: https://prometheus.io/docs/alerting/latest/configuration/#pushover_config

```yaml
receivers:
  - name: pushover-critical
    pushover_configs:
      - user_key: <from-secret>
        token: <from-secret>
        priority: 2  # emergency
        retry: 1m
        expire: 1h
        sound: siren
        title: '🚨 {{ .CommonLabels.alertname }}'
        message: '{{ .CommonAnnotations.description }}'
```

### 2. Healthchecks.io (hosted)

Dead man's switch - если сервис не пингует, алерт в Pushover.

**Free plan (Hobbyist):**
- 20 checks
- Pushover integration (native)
- Emergency priority support

Docs: https://healthchecks.io/pricing/

**Использование:**
- Критичные сервисы пингуют healthchecks каждые N минут
- Если пинг пропущен → алерт в Pushover

### 3. Notifier Service

Остаётся для user subscriptions через Telegram bot.
Не в critical path.

## План реализации

### Step 1: AlertManager Pushover Receiver

- [ ] Создать Pushover Application для AlertManager
- [ ] Добавить secrets в Doppler (PUSHOVER_API_TOKEN, PUSHOVER_USER_KEY)
- [ ] Добавить ExternalSecret в infrastructure
- [ ] Добавить pushover receiver в alertmanager-config.yaml
- [ ] Добавить route для critical → pushover
- [ ] Тест: trigger critical alert

### Step 2: Healthchecks.io Setup

- [ ] Создать аккаунт на healthchecks.io
- [ ] Подключить Pushover integration
- [ ] Создать checks для критичных сервисов:
  - [ ] alertmanager (watchdog ping)
  - [ ] prometheus
  - [ ] argocd
- [ ] Интегрировать watchdog alert → healthchecks ping

### Step 3: Documentation

- [ ] Обновить runbook
- [ ] Добавить в wiki

## Sources

- [AlertManager Pushover Config](https://prometheus.io/docs/alerting/latest/configuration/#pushover_config)
- [Healthchecks.io Pricing](https://healthchecks.io/pricing/)
- [Healthchecks.io Pushover Integration](https://healthchecks.io/docs/configuring_notifications/)
