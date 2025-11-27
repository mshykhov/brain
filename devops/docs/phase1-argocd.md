# Phase 1: ArgoCD Bootstrap

## На сервере (SSH)

```bash
# 1. ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 2. SSH ключ
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd -N ""
cat ~/.ssh/argocd.pub
# → GitHub repo → Settings → Deploy keys → Add (read-only)

# 3. Секрет для ArgoCD
kubectl create secret generic repo-example-infrastructure \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mshykhov/example-infrastructure.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd \
  -n argocd
kubectl label secret repo-example-infrastructure argocd.argoproj.io/secret-type=repository -n argocd

# 4. Склонировать репо
sudo apt install -y git
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/argocd
git clone git@github.com:mshykhov/example-infrastructure.git

# 5. GitOps
kubectl apply -f example-infrastructure/bootstrap/root.yaml

# 6. Проверка
kubectl get applications -n argocd -w
```

## Результат

```bash
kubectl get pods -n metallb-system
kubectl get pods -n longhorn-system
kubectl get ipaddresspool -n metallb-system
```
