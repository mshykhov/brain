# Setup Timeline

Пошаговая установка GitOps инфраструктуры на k3s.

**VM:** Ubuntu 24.04, 192.168.8.228
**Дата начала:** 2024-11-27

## Quick Start (Phase 0)

```bash
# На VM (Ubuntu 22.04+)
curl -O https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh
chmod +x phase0-setup.sh
sudo ./phase0-setup.sh
```

Или через scp:
```bash
# С локальной машины
scp phase0-setup.sh user@192.168.8.228:~/
ssh user@192.168.8.228 "chmod +x phase0-setup.sh && sudo ./phase0-setup.sh"
```

## Phases

| Phase | Компоненты | Статус |
|-------|-----------|--------|
| 0 | k3s, kubectl, helm, k9s | Done |
| 1 | MetalLB, Longhorn, ArgoCD | In Progress |
| 2 | GitOps (SSH, AppProjects, App-of-Apps) | Pending |
| 3 | Secrets (Doppler, ESO) | Pending |
| 4 | Networking (Traefik, Tailscale) | Pending |
| 5 | Data (PostgreSQL, Kafka) | Pending |
| 6 | Observability (Prometheus, Loki) | Pending |
| 7 | Backup (Velero, MinIO) | Pending |

## Файлы

- [metallb.md](metallb.md) - LoadBalancer для bare-metal
- [longhorn.md](longhorn.md) - Distributed storage
- [argocd.md](argocd.md) - GitOps CD
