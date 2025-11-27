# Phase 2: Коммит и пуш

## Порядок

1. Сначала `example-deploy` (там Helm charts)
2. Потом `example-infrastructure` (там ApplicationSet который ссылается на example-deploy)

## example-deploy

```bash
cd /path/to/example-deploy

# Проверить что есть
ls -la _library/
ls -la services/example-api/

# Коммит
git add .
git commit -m "feat: add library chart and example-api service"
git push
```

## example-infrastructure

```bash
cd /path/to/example-infrastructure

# Проверить что есть
ls -la apps/templates/services-appset.yaml

# Коммит
git add .
git commit -m "feat: add services ApplicationSet"
git push
```

## Проверка в ArgoCD

После пуша ArgoCD автоматически синхронизирует:

```bash
# Смотреть applications
kubectl get applications -n argocd -w

# Должен появиться example-api
kubectl get pods -n example-api
```

В ArgoCD UI: Applications → должен появиться `example-api`.

## Финальная проверка

```bash
# 1. ApplicationSet создан
kubectl get applicationsets -n argocd

# 2. Application появился
kubectl get applications -n argocd

# 3. Namespace создан
kubectl get ns example-api

# 4. Ресурсы созданы
kubectl get all -n example-api

# 5. Детали deployment
kubectl describe deployment -n example-api

# 6. События
kubectl get events -n example-api --sort-by='.lastTimestamp'
```

> **Ожидаемо:** Pod будет в статусе `ImagePullBackOff` или `ErrImagePull` — это нормально!
> Docker образ ещё не существует, и credentials для приватного registry ещё не настроены.
> Это исправим в Фазе 3 (Secrets) и Фазе 4 (CI/CD).

## Troubleshooting

### Application не появляется

```bash
# Проверить ApplicationSet
kubectl get applicationsets -n argocd
kubectl describe applicationset services -n argocd
```

### Ошибка синхронизации

```bash
# Логи ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Repository not found

Проверить что SSH ключ добавлен в оба репозитория и секреты созданы:

```bash
kubectl get secrets -n argocd | grep repo-
```
