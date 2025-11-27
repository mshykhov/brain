# Phase 1: ArgoCD

**Version:** v2.13.5
**Docs:** https://argo-cd.readthedocs.io/

## Установка (единственное что вручную!)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.5/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

## Подключение приватного репо

```bash
# Генерация ключа
ssh-keygen -t ed25519 -C "argocd" -f ~/.ssh/argocd-key -N ""

# Добавить публичный ключ в GitHub → repo → Settings → Deploy keys
cat ~/.ssh/argocd-key.pub

# Создать секрет
kubectl create secret generic repo-test-infrastructure \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mshykhov/test-infrastructure.git \
  --from-file=sshPrivateKey=~/.ssh/argocd-key \
  -n argocd
kubectl label secret repo-test-infrastructure argocd.argoproj.io/secret-type=repository -n argocd
```

## Bootstrap GitOps

```bash
kubectl apply -f https://raw.githubusercontent.com/mshykhov/test-infrastructure/main/bootstrap/root.yaml
```

## Доступ

```bash
# Пароль
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080 (admin / <password>)
```

## Проверка

```bash
kubectl get applications -n argocd
```
