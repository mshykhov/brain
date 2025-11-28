# Phase 2: ApplicationSet

**Docs:** https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/

## Зачем

Автоматически создаёт ArgoCD Application для каждого сервиса в `services/`.

## Подход: Git Directory Generator

Используем **Git Directory Generator** — простой и правильный способ:
- Сканирует папки в `services/*`
- Автоматически исключает папки начинающиеся с `_` (например `_library`)
- `.path.basename` = имя папки = имя приложения = namespace
- `.path.path` = полный путь к Helm chart

## Файл

`example-infrastructure/apps/templates/services-appset.yaml`

## ApplicationSet манифест

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: services
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "100"
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: git@github.com:mshykhov/example-deploy.git
        revision: HEAD
        directories:
          - path: services/*
          - path: services/_*
            exclude: true
  template:
    metadata:
      name: '{{ .path.basename }}'
    spec:
      project: default
      source:
        repoURL: git@github.com:mshykhov/example-deploy.git
        targetRevision: HEAD
        path: '{{ .path.path }}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{ .path.basename }}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

> **Важно:** В реальном файле (внутри Helm chart) Go template экранируется backticks:
> `` '{{`{{ .path.basename }}`}}' ``

## Как работает

1. Git Directory Generator сканирует `services/*`
2. Исключает папки `services/_*` (library charts)
3. Для каждой папки создаёт Application
4. `{{ .path.basename }}` = `example-api`
5. `{{ .path.path }}` = `services/example-api`
6. Автоматический sync + создание namespace

## Добавление нового сервиса

Просто создай папку в `services/`:

```
example-deploy/services/new-service/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── deployment.yaml
    ├── service.yaml
    └── serviceaccount.yaml
```

ArgoCD автоматически подхватит и задеплоит.

## Sync Wave

Wave 100 — после всей инфраструктуры (MetalLB, Longhorn, ESO).

## Проверка

```bash
kubectl get applicationsets -n argocd
kubectl get applications -n argocd
kubectl get pods -n example-api
```
