# Phase 2: ApplicationSet

**Docs:** https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/

## Зачем

Автоматически создаёт ArgoCD Application для каждой папки в `services/`.

## Файл

`example-infrastructure/apps/templates/services-appset.yaml`

## Манифест

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: services
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
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
            exclude: true  # Исключить _library и подобные
  template:
    metadata:
      name: '{{.path.basename}}'
    spec:
      project: default
      source:
        repoURL: git@github.com:mshykhov/example-deploy.git
        targetRevision: HEAD
        path: '{{.path.path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.path.basename}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Как работает

1. Git Generator сканирует `services/*` в example-deploy
2. Для каждой папки (кроме `_*`) создаёт Application
3. `{{.path.basename}}` = имя папки = имя приложения = namespace
4. Автоматический sync + создание namespace

## Sync Wave

Wave 10 — после всей инфраструктуры (MetalLB, Longhorn, ESO).

## Проверка

```bash
kubectl get applicationsets -n argocd
kubectl get applications -n argocd
```
