# Phase 10: Alerting & Notifications

## Overview

Production-ready alerting с Telegram notifications через Topics:
- **Alertmanager** - routing alerts по severity
- **Telegram Topics** - structured notifications в одной группе
- **Inhibit Rules** - подавление noise
- **ArgoCD Notifications** - deployment alerts

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Prometheus                               │
│                    (scrapes metrics)                             │
└─────────────────────────┬───────────────────────────────────────┘
                          │ firing alerts
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Alertmanager                               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Grouping   │→ │  Routing    │→ │  Inhibition/Silencing   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────┬───────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ Critical │    │ Warning  │    │   Info   │
    │  Topic   │    │  Topic   │    │  Topic   │
    └──────────┘    └──────────┘    └──────────┘
                          │
                          ▼
            ┌─────────────────────────┐
            │   Telegram Group        │
            │   "Homelab Alerts"      │
            │   (with Topics enabled) │
            └─────────────────────────┘
```

## Components

| Component | Description |
|-----------|-------------|
| Alertmanager | Routes alerts to receivers based on labels |
| Telegram Bot | Sends notifications via Bot API |
| Topics | Threads within single Telegram group |
| Inhibit Rules | Suppress redundant alerts |
| Templates | Custom message formatting |

## Documentation

1. [Telegram Setup](01-telegram-setup.md) - Bot, group, topics creation
2. [Alertmanager Config](02-alertmanager-config.md) - Routing, receivers, templates
3. [Built-in Alerts](03-builtin-alerts.md) - Important kube-prometheus alerts
4. [ArgoCD Notifications](04-argocd-notifications.md) - Deployment notifications
5. [Testing & Verification](05-testing.md) - How to test alerting

## Key Decisions

1. **Topics vs Multiple Groups** - Topics cleaner, single group
2. **HTML parse_mode** - More reliable than MarkdownV2
3. **Inhibit Rules** - Critical suppresses Warning for same alert
4. **Secrets in Doppler** - Bot token, chat IDs

## Doppler Secrets

| Key | Description |
|-----|-------------|
| `TELEGRAM_BOT_TOKEN` | Bot token from @BotFather |
| `TELEGRAM_CHAT_ID` | Group chat ID (negative number) |
| `TELEGRAM_TOPIC_CRITICAL` | Thread ID for critical alerts |
| `TELEGRAM_TOPIC_WARNING` | Thread ID for warning alerts |
| `TELEGRAM_TOPIC_INFO` | Thread ID for info/resolved |
| `TELEGRAM_TOPIC_DEPLOYS` | Thread ID for ArgoCD deploys |

## Official Sources

- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [kube-prometheus-stack Alerts](https://github.com/prometheus-operator/kube-prometheus)
- [ArgoCD Notifications](https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/)
