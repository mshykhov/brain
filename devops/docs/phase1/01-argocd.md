# Phase 1: ArgoCD Bootstrap

## На сервере (SSH)

### 1. Установить ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

### 2. Создать SSH ключ

```bash
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd -N ""
cat ~/.ssh/argocd.pub
```

### 3. Добавить Deploy Key в GitHub

1. GitHub → `example-infrastructure` → Settings → Deploy keys → Add deploy key
2. Title: `argocd`
3. Key: содержимое `~/.ssh/argocd.pub`
4. ✅ Allow write access (не нужно, read-only достаточно)

### 4. Создать секрет для ArgoCD

```bash
kubectl create secret generic repo-example-infrastructure \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mshykhov/example-infrastructure.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd \
  -n argocd
kubectl label secret repo-example-infrastructure argocd.argoproj.io/secret-type=repository -n argocd
```

### 5. Склонировать репо

```bash
sudo apt install -y git
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/argocd
git clone git@github.com:mshykhov/example-infrastructure.git
```

### 6. Запустить GitOps

```bash
kubectl apply -f example-infrastructure/bootstrap/root.yaml
```

### 7. Следить за синхронизацией

```bash
kubectl get applications -n argocd -w
```

## ArgoCD UI

### Получить пароль

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### Port forward

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0
```

Доступ через Tailscale: `https://<tailscale-ip>:8080`

## Результат

После синхронизации автоматически установятся:
- MetalLB (wave 1-2)
- Longhorn (wave 3)

```bash
kubectl get pods -n metallb-system
kubectl get pods -n longhorn-system
kubectl get ipaddresspool -n metallb-system
```

## Следующий шаг

[Phase 2: GitOps Structure](../phase2/gitops-structure.md)
