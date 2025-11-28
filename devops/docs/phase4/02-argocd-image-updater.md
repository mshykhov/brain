# Phase 4: ArgoCD Image Updater

## Зачем

ArgoCD Image Updater автоматически отслеживает новые версии Docker образов и обновляет ArgoCD Applications. Это завершает CI/CD pipeline: push tag → build → push image → auto-update deployment.

## Архитектура

```
GitHub Actions              Docker Hub           ArgoCD Image Updater
     │                          │                        │
     ├─── push image ───────────►                        │
     │    shykhov/example-api:0.1.0                      │
     │                          │                        │
     │                          │◄──── poll (2min) ──────┤
     │                          │                        │
     │                          ├─── new tag found ──────►
     │                          │                        │
     │                                            ┌──────┴──────┐
     │                                            │  Update     │
     │                                            │  Application │
     │                                            │  spec       │
     │                                            └──────┬──────┘
     │                                                   │
     │                                                   ▼
     │                                            ArgoCD syncs
     │                                            new image
```

## 1. Установка через ArgoCD (GitOps)

### Файл манифеста

`example-infrastructure/apps/templates/argocd-image-updater.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-image-updater
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "7"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argocd-image-updater
    targetRevision: "1.0.1"
    helm:
      values: |
        config:
          registries:
            - name: Docker Hub
              api_url: https://registry-1.docker.io
              prefix: docker.io
              ping: yes
              defaultns: library
              default: true
          log.level: info
        metrics:
          enabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Helm Chart Info

| Параметр | Значение |
|----------|----------|
| Repository | `https://argoproj.github.io/argo-helm` |
| Chart | `argocd-image-updater` |
| Version | `1.0.1` |
| App Version | `v1.0.1` |

## 2. Аннотации для Applications

Image Updater использует аннотации на ArgoCD Application для конфигурации.

### Базовые аннотации

```yaml
metadata:
  annotations:
    # Образ для отслеживания: alias=registry/image:constraint
    argocd-image-updater.argoproj.io/image-list: app=docker.io/shykhov/example-api:~0

    # Стратегия обновления
    argocd-image-updater.argoproj.io/app.update-strategy: semver

    # Helm параметр для тега
    argocd-image-updater.argoproj.io/app.helm.image-tag: image.tag

    # Метод записи
    argocd-image-updater.argoproj.io/write-back-method: argocd
```

### Объяснение аннотаций

| Аннотация | Описание |
|-----------|----------|
| `image-list` | Список образов: `alias=image:constraint` |
| `update-strategy` | `semver` (по semver), `latest` (по дате), `digest` (по sha) |
| `helm.image-tag` | Helm параметр для записи тега |
| `write-back-method` | `argocd` (в spec) или `git` (коммит в репо) |

### Semver Constraints

| Constraint | Описание | Пример |
|------------|----------|--------|
| `~0` | Latest patch in 0.x | 0.1.0 → 0.1.5, 0.2.0 |
| `1.x` | Any 1.x.x | 1.0.0 → 1.5.2 |
| `1.2.x` | Only 1.2.x patches | 1.2.0 → 1.2.5 |
| `^1.0` | Compatible with 1.0 | 1.0.0 → 1.9.9 |
| `>=1.0 <2.0` | Range | 1.0.0 → 1.9.9 |

## 3. ApplicationSet с Image Updater

В `services-appset.yaml` добавлены аннотации:

```yaml
template:
  metadata:
    name: '{{ .path.basename }}'
    annotations:
      # Образ: shykhov/<service-name>:~0 (latest 0.x)
      argocd-image-updater.argoproj.io/image-list: 'app=docker.io/shykhov/{{ .path.basename }}:~0'
      argocd-image-updater.argoproj.io/app.update-strategy: semver
      argocd-image-updater.argoproj.io/app.helm.image-tag: image.tag
      argocd-image-updater.argoproj.io/write-back-method: argocd
```

### Как это работает

1. ApplicationSet создаёт Application `example-api`
2. Image Updater видит аннотацию `image-list`
3. Каждые 2 минуты проверяет Docker Hub на новые теги
4. При новом теге (например `0.1.1`) обновляет Application spec
5. ArgoCD синхронизирует deployment с новым образом

## 4. Write-back Methods

### Method: argocd (рекомендуется для начала)

```yaml
argocd-image-updater.argoproj.io/write-back-method: argocd
```

- Обновляет `spec.source.helm.parameters` в Application
- Никаких коммитов в Git
- Быстро, просто
- **Минус:** при ресинке Application тег сбросится

### Method: git (для production)

```yaml
argocd-image-updater.argoproj.io/write-back-method: git
argocd-image-updater.argoproj.io/write-back-target: helmvalues:values.yaml
argocd-image-updater.argoproj.io/git-branch: master
```

- Коммитит изменения в Git репозиторий
- Полный GitOps (всё в Git)
- Требует настройки SSH/token для push

## 5. Проверка

### После sync

```bash
# Проверить pod
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# Логи
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f

# Список отслеживаемых приложений
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater | grep "Processing"
```

### Тест обновления

```bash
# 1. Создать новый тег в example-api
cd /path/to/example-api
git tag v0.1.1
git push origin v0.1.1

# 2. Дождаться GitHub Actions (build + push)

# 3. Через 2 минуты Image Updater обнаружит новый тег

# 4. Проверить Application
kubectl get app example-api -n argocd -o yaml | grep -A5 "helm:"
```

## Troubleshooting

### Image Updater не видит приложение

```bash
# Проверить аннотации
kubectl get app example-api -n argocd -o jsonpath='{.metadata.annotations}'
```

Должна быть аннотация `argocd-image-updater.argoproj.io/image-list`.

### Не находит новые теги

```bash
# Тест подключения к registry
kubectl exec -n argocd deploy/argocd-image-updater -- \
  argocd-image-updater test docker.io/shykhov/example-api
```

### Rate limiting Docker Hub

Для anonymous: 100 pulls/6 hours. Решение — добавить credentials:

```yaml
config:
  registries:
    - name: Docker Hub
      api_url: https://registry-1.docker.io
      prefix: docker.io
      credentials: pullsecret:argocd/dockerhub-creds
```

## Итоговая структура

```
example-infrastructure/apps/templates/
├── argocd-image-updater.yaml  # Wave 7
└── services-appset.yaml       # Wave 100, с аннотациями Image Updater
```

## CI/CD Flow (полный)

```
1. Developer: git tag v0.1.1 && git push --tags
                    │
2. GitHub Actions:  ├─► Build Docker image
                    ├─► Push to Docker Hub (0.1.1, 0.1, latest)
                    │
3. Image Updater:   ├─► Poll Docker Hub (каждые 2 мин)
                    ├─► Найден новый тег 0.1.1
                    ├─► Update Application spec
                    │
4. ArgoCD:          └─► Sync deployment с новым образом
```

## Следующий шаг

Тест полного цикла CI/CD:
1. Commit и push в example-api
2. Создать тег и push
3. Дождаться GitHub Actions
4. Проверить автообновление в кластере
