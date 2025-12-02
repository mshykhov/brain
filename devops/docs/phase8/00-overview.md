# Phase 8: Observability

## Overview

Полный стек мониторинга для Kubernetes:
- **Prometheus** - сбор и хранение метрик
- **Grafana** - визуализация (за oauth2-proxy)
- **Loki** - агрегация логов
- **Alloy** - сбор логов (замена deprecated Promtail)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Grafana                               │
│              (anonymous mode, oauth2-proxy)                  │
└─────────────────┬───────────────────────┬───────────────────┘
                  │                       │
                  ▼                       ▼
┌─────────────────────────┐   ┌─────────────────────────────┐
│       Prometheus        │   │           Loki              │
│    (metrics storage)    │   │      (log storage)          │
│    retention: 15d       │   │    retention: 7d            │
└────────────┬────────────┘   └──────────────┬──────────────┘
             │                               │
             │                               │
    ┌────────┴────────┐             ┌────────┴────────┐
    │  ServiceMonitor │             │     Alloy       │
    │   (scrape pods) │             │  (collect logs) │
    └─────────────────┘             └─────────────────┘
```

## Components

| Component | Chart Version | App Version | Mode |
|-----------|---------------|-------------|------|
| kube-prometheus-stack | 79.10.0 | 0.86.2 | Full stack |
| Loki | 6.46.0 | 3.5.7 | SingleBinary |
| Alloy | 1.4.0 | 1.11.3 | DaemonSet |

## Sync Waves

| Wave | Component |
|------|-----------|
| 30 | kube-prometheus-stack |
| 32 | Loki |
| 33 | Alloy |

## Access

- **URL**: `https://grafana.<tailnet>/`
- **Auth**: oauth2-proxy (Auth0)
- **Groups**: `infra-admins`, `monitoring-admins`

## Official Docs

- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Anonymous Auth](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/anonymous-auth)
- [Loki Helm Install](https://grafana.com/docs/loki/latest/setup/install/helm/)
- [Grafana Alloy](https://grafana.com/docs/alloy/latest/)
- [ServiceMonitor](https://prometheus-operator.dev/docs/api-reference/api/#monitoring.coreos.com/v1.ServiceMonitor)
