# Phase 2: SSH ключ для example-deploy

## Зачем

ArgoCD нужен доступ к `example-deploy` репозиторию чтобы читать Helm charts для сервисов.

> **Важно:** GitHub не позволяет использовать один deploy key для нескольких репозиториев. Поэтому создаём отдельный ключ.

## На сервере (SSH)

### 1. Создать новый SSH ключ

```bash
ssh-keygen -t ed25519 -C "argocd-deploy" -f ~/.ssh/argocd-deploy -N ""
```

### 2. Показать публичный ключ

```bash
cat ~/.ssh/argocd-deploy.pub
```

Скопировать содержимое.

### 3. Добавить Deploy Key в GitHub

1. GitHub → `example-deploy` → Settings → Deploy keys
2. Add deploy key
3. Title: `argocd-deploy`
4. Key: вставить содержимое `~/.ssh/argocd-deploy.pub`
5. ❌ Allow write access (не нужно, read-only)
6. Add key

### 4. Создать секрет в ArgoCD

```bash
kubectl create secret generic repo-example-deploy \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mshykhov/example-deploy.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd-deploy \
  -n argocd

kubectl label secret repo-example-deploy argocd.argoproj.io/secret-type=repository -n argocd
```

## Проверка

```bash
kubectl get secret repo-example-deploy -n argocd
```

В ArgoCD UI: Settings → Repositories → должен быть `example-deploy` со статусом Connected.

## SSH ключи

| Ключ | Репозиторий |
|------|-------------|
| ~/.ssh/argocd | example-infrastructure |
| ~/.ssh/argocd-deploy | example-deploy |
