# Phase 2: GitOps Structure

## Репозитории

| Репо | Назначение |
|------|------------|
| example-api | Исходный код приложения (Kotlin/Spring Boot) |
| example-deploy | Helm charts для деплоя |
| example-infrastructure | Platform (ArgoCD, MetalLB, Longhorn, ESO) |

## Шаги

### 1. Создать Library Chart

```
example-deploy/
├── _library/
│   ├── Chart.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── _util.tpl
│       ├── _deployment.tpl
│       ├── _service.tpl
│       └── _serviceaccount.tpl
```

Подробнее: [Library Chart](library-chart.md)

### 2. Создать Service Chart

```
example-deploy/
└── services/
    └── example-api/
        ├── Chart.yaml
        ├── values.yaml
        └── templates/
            ├── deployment.yaml
            ├── service.yaml
            └── serviceaccount.yaml
```

Подробнее: [Service Chart](service-chart.md)

### 3. Создать ApplicationSet

```
example-infrastructure/
└── apps/templates/services-appset.yaml
```

Подробнее: [ApplicationSet](applicationset.md)

### 4. Добавить SSH ключ для example-deploy

Подробнее: [SSH Key Deploy](ssh-key-deploy.md)

### 5. Закоммитить и запушить

Подробнее: [Commit & Push](commit-push.md)

## Проверка

```bash
kubectl get applications -n argocd
kubectl get pods -n example-api
```
