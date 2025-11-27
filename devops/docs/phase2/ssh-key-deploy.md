# Phase 2: SSH ключ для example-deploy

## Зачем

ArgoCD нужен доступ к `example-deploy` репозиторию чтобы читать Helm charts для сервисов.

## На сервере (SSH)

### 1. Показать публичный ключ

```bash
cat ~/.ssh/argocd.pub
```

Скопировать содержимое.

### 2. Добавить Deploy Key в GitHub

1. GitHub → `example-deploy` → Settings → Deploy keys
2. Add deploy key
3. Title: `argocd`
4. Key: вставить содержимое `~/.ssh/argocd.pub`
5. ❌ Allow write access (не нужно, read-only)
6. Add key

### 3. Создать секрет в ArgoCD

```bash
kubectl create secret generic repo-example-deploy \
  --from-literal=type=git \
  --from-literal=url=git@github.com:mshykhov/example-deploy.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd \
  -n argocd

kubectl label secret repo-example-deploy argocd.argoproj.io/secret-type=repository -n argocd
```

## Проверка

```bash
kubectl get secret repo-example-deploy -n argocd
```

В ArgoCD UI: Settings → Repositories → должен быть `example-deploy` со статусом Connected.
