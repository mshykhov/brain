# Phase 2: ApplicationSet

**Docs:** https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/

## Зачем

Автоматически создаёт ArgoCD Application для каждого сервиса в `services/`.

## Подход: Git Files Generator

Используем **Git Files Generator** вместо Directory Generator:
- Каждый сервис имеет `config.json` с настройками
- Можно задать индивидуальные параметры для каждого микросервиса
- Гибче для разных конфигураций

## Файлы

```
example-infrastructure/apps/templates/services-appset.yaml  # ApplicationSet
example-deploy/services/example-api/config.json             # Конфиг сервиса
```

## config.json (в каждом сервисе)

```json
{
  "name": "example-api",
  "namespace": "example-api",
  "project": "default"
}
```

Можно расширять любыми полями для кастомизации.

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
        files:
          - path: "services/**/config.json"
  template:
    metadata:
      name: '{{ .name }}'
    spec:
      project: '{{ .project }}'
      source:
        repoURL: git@github.com:mshykhov/example-deploy.git
        targetRevision: HEAD
        path: '{{ .path.path | dir }}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{ .namespace }}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

> **Важно:** В реальном файле (внутри Helm chart) Go template синтаксис экранируется:
> `'{{` + `` ` `` + `{{ .name }}` + `` ` `` + `}}'`

## Как работает

1. Git Files Generator сканирует `services/**/config.json`
2. Читает JSON и делает поля доступными как переменные
3. `{{ .name }}` — имя из config.json
4. `{{ .path.path | dir }}` — путь к папке сервиса
5. Автоматический sync + создание namespace

## Sync Wave

Wave 100 — после всей инфраструктуры (MetalLB, Longhorn, ESO).

## Проверка

```bash
kubectl get applicationsets -n argocd
kubectl get applications -n argocd
```
