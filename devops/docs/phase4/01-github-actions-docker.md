# Phase 4: GitHub Actions - Docker Build & Push

## Зачем

GitHub Actions автоматически билдит Docker образ и пушит в DockerHub при создании тега. Это первый шаг CI/CD pipeline.

## Архитектура

```
Developer                    GitHub Actions              Docker Hub
    │                             │                          │
    ├─── git tag v1.0.0 ──────────►                          │
    ├─── git push --tags ─────────►                          │
    │                             │                          │
    │                      ┌──────┴──────┐                   │
    │                      │  Workflow   │                   │
    │                      │  Triggered  │                   │
    │                      └──────┬──────┘                   │
    │                             │                          │
    │                      ┌──────┴──────┐                   │
    │                      │ Validate    │                   │
    │                      │ Semver Tag  │                   │
    │                      └──────┬──────┘                   │
    │                             │                          │
    │                      ┌──────┴──────┐                   │
    │                      │ Build Image │                   │
    │                      └──────┬──────┘                   │
    │                             │                          │
    │                             ├─── push ─────────────────►
    │                             │    shykhov/example-api:1.0.0
    │                             │    shykhov/example-api:1.0
    │                             │    shykhov/example-api:1
    │                             │    shykhov/example-api:latest
    │                             │                          │
```

## Что такое Semver

**Semantic Versioning** — стандарт версионирования: `MAJOR.MINOR.PATCH`

```
v1.2.3
│ │ └── PATCH: баг-фиксы (обратно совместимые)
│ └──── MINOR: новые фичи (обратно совместимые)
└────── MAJOR: breaking changes (несовместимые)
```

**Примеры:**
- `1.0.0 → 1.0.1` — исправили баг
- `1.0.1 → 1.1.0` — добавили фичу
- `1.1.0 → 2.0.0` — сломали обратную совместимость

**Pre-release версии:**
- `v2.0.0-alpha.1` — альфа
- `v2.0.0-beta.1` — бета
- `v2.0.0-rc.1` — release candidate

> **Важно:** Major version zero (`v0.x.x`) означает начальную разработку — API нестабилен.

## 1. Создание Docker Hub Access Token

### Для GitHub Actions (Read & Write)

1. https://hub.docker.com/settings/security
2. **New Access Token**
3. **Description:** `github-actions-example-api`
4. **Access permissions:** `Read & Write`
5. **Generate** → скопируй токен

> **Важно:** Токен показывается один раз! Сохрани его.

### Итого токенов в Docker Hub

| Токен | Permissions | Использование |
|-------|-------------|---------------|
| `k8s-pull` | Read-only | Kubernetes pull images |
| `github-actions-example-api` | Read & Write | CI/CD push images |

## 2. Настройка GitHub Secrets

1. Перейди в репозиторий `example-api` на GitHub
2. **Settings** → **Secrets and variables** → **Actions**
3. **New repository secret**

### Добавить секреты:

| Name | Value |
|------|-------|
| `DOCKERHUB_USERNAME` | `shykhov` (твой Docker Hub username) |
| `DOCKERHUB_TOKEN` | `dckr_pat_xxx...` (токен с Read & Write) |

## 3. Workflow файл

Создай файл `.github/workflows/docker.yaml` в репозитории `example-api`:

```yaml
# =============================================================================
# DOCKER BUILD & PUSH WORKFLOW
# =============================================================================
# Triggers: Push semantic version tags (v*)
# Registry: Docker Hub
#
# Tag examples:
#   v1.2.3 -> 1.2.3, 1.2, 1, latest
#   v0.1.0 -> 0.1.0, 0.1 (no 0 tag for major version zero)
#   v2.0.0-beta.1 -> 2.0.0-beta.1 (pre-release, no latest)
# =============================================================================
name: Docker Build & Push

on:
  push:
    tags:
      - 'v*.*.*'

env:
  IMAGE_NAME: shykhov/example-api

jobs:
  build:
    name: Build and Push
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Validate semver tag
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
            echo "::error::Tag '$TAG' is not valid semver (expected: vX.Y.Z)"
            exit 1
          fi
          echo "Valid semver tag: $TAG"

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract metadata (tags, labels)
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
          flavor: |
            latest=auto

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: mode=max
          sbom: true

      - name: Output image info
        run: |
          echo "## Docker Image Published" >> $GITHUB_STEP_SUMMARY
          echo "**Image:** \`${{ env.IMAGE_NAME }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Tags:**" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          echo "${{ steps.meta.outputs.tags }}" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
```

## 4. Понимание workflow

### Триггер

```yaml
on:
  push:
    tags:
      - 'v*.*.*'
```

Workflow запускается только при push тегов формата `v*.*.*` (например `v1.0.0`).

### Валидация semver

```bash
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
  exit 1
fi
```

Проверяет что тег соответствует формату:
- ✅ `v1.0.0`
- ✅ `v2.1.3-beta.1`
- ❌ `v1.0`
- ❌ `release-1.0.0`

### Генерация тегов

```yaml
tags: |
  type=semver,pattern={{version}}      # v1.2.3 -> 1.2.3
  type=semver,pattern={{major}}.{{minor}}  # v1.2.3 -> 1.2
  type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}
```

| Git Tag | Docker Tags |
|---------|-------------|
| `v1.2.3` | `1.2.3`, `1.2`, `1`, `latest` |
| `v0.1.0` | `0.1.0`, `0.1` |
| `v2.0.0-beta.1` | `2.0.0-beta.1` |

### Почему нет тега `0` для v0.x.x?

Major version zero означает "начальная разработка" — API нестабилен. Тег `0` будет постоянно перезаписываться, что бесполезно.

### Кеширование

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

Использует GitHub Actions cache для ускорения билдов.

### Security attestations

```yaml
provenance: mode=max
sbom: true
```

- **Provenance** — информация о том как и где был собран образ
- **SBOM** (Software Bill of Materials) — список всех зависимостей

## 5. Commit и Push

```bash
cd /path/to/example-api

# Добавить workflow
git add .github/workflows/docker.yaml
git commit -m "feat: add Docker build workflow"
git push origin master
```

## 6. Создание первого релиза

```bash
# Создать тег
git tag v0.1.0

# Запушить тег (это триггерит workflow)
git push origin v0.1.0
```

## 7. Проверка

### GitHub Actions

1. GitHub → `example-api` → **Actions**
2. Должен появиться workflow "Docker Build & Push"
3. Проверь что статус ✅

### Docker Hub

1. https://hub.docker.com/r/shykhov/example-api/tags
2. Должны появиться теги: `0.1.0`, `0.1`, `latest`

### Локально

```bash
docker pull shykhov/example-api:0.1.0
docker run --rm -p 8080:8080 shykhov/example-api:0.1.0
curl http://localhost:8080/actuator/health
```

## Troubleshooting

### Workflow не запускается

- Проверь что тег соответствует паттерну `v*.*.*`
- Проверь что workflow файл в ветке `master`/`main`

### Login failed

- Проверь секреты `DOCKERHUB_USERNAME` и `DOCKERHUB_TOKEN`
- Проверь что токен имеет права `Read & Write`

### Build failed

- Проверь Dockerfile
- Проверь что все файлы есть в репозитории

## Следующий шаг

[02. ArgoCD Image Updater](02-argocd-image-updater.md)
