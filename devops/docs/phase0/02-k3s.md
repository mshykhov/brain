# Phase 0: k3s + Tools

## Автоматическая установка

```bash
curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/phase0-setup.sh | sudo bash
```

## Ручная установка

### 1. k3s

```bash
# Установка БЕЗ traefik и servicelb (у нас свои)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable=traefik --disable=servicelb" sh -

# Настроить kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config
```

### 2. kubectl

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

### 3. Helm

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### 4. k9s

```bash
curl -sS https://webinstall.dev/k9s | bash
```

### 5. open-iscsi (для Longhorn)

```bash
sudo apt update && sudo apt install -y open-iscsi
sudo systemctl enable --now iscsid
```

## Компоненты

| Компонент | Версия | Назначение |
|-----------|--------|------------|
| k3s | latest | Kubernetes |
| kubectl | latest | CLI |
| helm | latest | Package manager |
| k9s | latest | TUI |
| open-iscsi | - | Storage (Longhorn) |

## Проверка

```bash
kubectl get nodes
kubectl get pods -A
helm version
k9s --version
```

## Следующий шаг

[Phase 1: ArgoCD](../phase1/argocd.md)
