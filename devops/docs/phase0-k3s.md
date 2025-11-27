# Phase 0: k3s + Tools

## Установка

```bash
curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh | sudo bash
```

## Что устанавливается

| Компонент | Версия | Назначение |
|-----------|--------|------------|
| k3s | latest | Kubernetes |
| kubectl | latest | CLI |
| helm | latest | Package manager |
| k9s | latest | TUI |

## Особенности k3s

```bash
# Установка БЕЗ traefik и servicelb (у нас свои)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb" sh -
```

## Проверка

```bash
kubectl get nodes
kubectl get pods -A
```
