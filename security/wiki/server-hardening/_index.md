---
tags: [server, k3s, ovh, bare-metal]
---

# Server Hardening Guide

Пошаговое руководство по защите bare metal сервера OVH с k3s кластером.

## Инфраструктура

- **Сервер**: OVH Bare Metal
- **Кластер**: K3s (single node, later multi-node)
- **Доступ**: SSH → Tailscale → Tailscale K8s Operator
- **Secrets**: Keeper (password manager)

## Шаги настройки

| # | Этап | Статус |
|---|------|--------|
| 1 | [SSH Hardening](01-ssh-hardening.md) | ⬜ |
| 2 | [Firewall Setup](02-firewall-setup.md) | ⬜ |
| 3 | [K3s Secrets Encryption](03-k3s-secrets-encryption.md) | ⬜ |
| 4 | [K3s Hardening](04-k3s-hardening.md) | ⬜ |
| 5 | [Tailscale Setup](05-tailscale-setup.md) | ⬜ |
| 6 | [Network Policies](06-network-policies.md) | ⬜ |

## Принципы

- Defense in depth (многоуровневая защита)
- Principle of least privilege
- Zero trust networking (через Tailscale)
