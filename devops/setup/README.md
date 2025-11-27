# Setup Timeline

Пошаговая установка GitOps инфраструктуры на k3s.

**VM:** Ubuntu 24.04, 192.168.8.228
**Дата начала:** 2024-11-27
**Репо:** https://github.com/mshykhov/test-monorepo

## Bootstrap (Phase 0 + 1)

### Phase 0: k3s + tools
```bash
curl -O https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh
chmod +x phase0-setup.sh && sudo ./phase0-setup.sh
```

### Phase 1: ArgoCD + GitOps
```bash
# 1. Установить ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml

# 2. Дождаться готовности
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

# 3. Применить root Application (App-of-Apps)
kubectl apply -f https://raw.githubusercontent.com/mshykhov/test-monorepo/main/infrastructure/bootstrap/root.yaml

# 4. Получить пароль
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

После этого ArgoCD автоматически задеплоит MetalLB, Longhorn и всё остальное из Git.

## Phases

| Phase | Компоненты | Способ | Статус |
|-------|-----------|--------|--------|
| 0 | k3s, kubectl, helm, k9s | Скрипт | Done |
| 1 | ArgoCD (bootstrap) | kubectl | In Progress |
| 1 | MetalLB, Longhorn | GitOps | Pending |
| 2 | SSH keys, App-of-Apps | GitOps | Pending |
| 3 | Secrets (Doppler, ESO) | GitOps | Pending |
| 4 | Networking (Traefik, Tailscale) | Pending |
| 5 | Data (PostgreSQL, Kafka) | Pending |
| 6 | Observability (Prometheus, Loki) | Pending |
| 7 | Backup (Velero, MinIO) | Pending |

## Файлы

- [metallb.md](metallb.md) - LoadBalancer для bare-metal
- [longhorn.md](longhorn.md) - Distributed storage
- [argocd.md](argocd.md) - GitOps CD
