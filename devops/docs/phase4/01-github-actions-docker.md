# Phase 4: GitHub Actions - Multi-Platform Docker Build

## Зачем

GitHub Actions автоматически билдит multi-platform Docker образ и пушит в DockerHub при создании тега. Поддерживает pre-release теги для тестирования в dev перед production.

## Архитектура

```
Developer                    GitHub Actions              Docker Hub
    │                             │                          │
    ├─── git tag v0.1.0-rc.1 ─────►                          │
    ├─── git push --tags ─────────►                          │
    │                             │                          │
    │                      ┌──────┴──────┐                   │
    │                      │  Workflow   │                   │
    │                      │  Triggered  │                   │
    │                      └──────┬──────┘                   │
    │                             │                          │
    │                      ┌──────┴──────┐                   │
    │                      │ Multi-arch  │                   │
    │                      │ Build       │                   │
    │                      │ amd64+arm64 │                   │
    │                      └──────┬──────┘                   │
    │                             │                          │
    │                             ├─── push ─────────────────►
    │                             │    user/app:0.1.0-rc.1   │
    │                             │                          │
```

## Workflow: Dev → Prd

```
1. v0.1.0-rc.1  ──► builds ──► DEV auto-deploy (pre-release)
2. Test in DEV
3. v0.1.0       ──► builds ──► PRD auto-deploy (stable)
```

## Semver + Pre-release

**Semantic Versioning:** `MAJOR.MINOR.PATCH[-PRERELEASE]`

| Тег | Docker Tags | Environment |
|-----|-------------|-------------|
| `v0.1.0-rc.1` | `0.1.0-rc.1` | DEV only |
| `v0.1.0-beta.2` | `0.1.0-beta.2` | DEV only |
| `v0.1.0` | `0.1.0` | DEV + PRD |
| `v1.2.3` | `1.2.3`, `1` | DEV + PRD |

## 1. Docker Hub Access Token

1. https://hub.docker.com/settings/security
2. **New Access Token**
3. **Description:** `github-actions`
4. **Access permissions:** `Read & Write`
5. **Generate** → скопируй токен

## 2. GitHub Secrets

Repository → **Settings** → **Secrets and variables** → **Actions**:

| Name | Value |
|------|-------|
| `DOCKERHUB_USERNAME` | твой Docker Hub username |
| `DOCKERHUB_TOKEN` | токен с Read & Write |

## 3. Workflow файл

`.github/workflows/release.yaml`:

```yaml
# =============================================================================
# RELEASE WORKFLOW - BUILD & PUSH MULTI-PLATFORM DOCKER IMAGE
# =============================================================================
# Triggers: Push semantic version tags (v*)
# Registry: Docker Hub
# Platforms: linux/amd64, linux/arm64
#
# Workflow:
#   1. Push v0.1.0-rc.1 -> builds 0.1.0-rc.1 -> deploys to DEV (auto)
#   2. Test in DEV environment
#   3. Push v0.1.0 -> builds 0.1.0 -> deploys to PRD (auto)
#
# Tag examples:
#   v0.1.0-rc.1  -> 0.1.0-rc.1 (pre-release, DEV only)
#   v0.1.0-beta.2 -> 0.1.0-beta.2 (pre-release, DEV only)
#   v0.1.0       -> 0.1.0 (stable, PRD)
#   v1.2.3       -> 1.2.3, 1 (stable, PRD)
#
# Required secrets:
#   DOCKERHUB_USERNAME - Docker Hub username
#   DOCKERHUB_TOKEN    - Docker Hub Access Token (Read & Write)
# =============================================================================
name: Release

on:
  push:
    tags:
      - 'v[0-9]+.[0-9]+.[0-9]+*'

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  docker:
    name: Build and Push
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v5

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ secrets.DOCKERHUB_USERNAME }}/${{ github.event.repository.name }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}},enable=${{ !startsWith(github.ref, 'refs/tags/v0.') }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: |
            APP_VERSION=${{ steps.meta.outputs.version }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

## 4. Ключевые особенности

### Multi-platform build

```yaml
platforms: linux/amd64,linux/arm64
```

Один образ работает на x86 серверах и ARM (Raspberry Pi, Apple Silicon).

### Dynamic image name

```yaml
images: ${{ secrets.DOCKERHUB_USERNAME }}/${{ github.event.repository.name }}
```

Нет hardcoded значений — работает для любого репозитория.

### App version injection

```yaml
build-args: |
  APP_VERSION=${{ steps.meta.outputs.version }}
```

Версия из git tag передаётся в Docker build для Spring Boot `buildInfo()`.

### Concurrency control

```yaml
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false
```

Предотвращает одновременные билды одного тега.

### Tag pattern

```yaml
tags:
  - 'v[0-9]+.[0-9]+.[0-9]+*'
```

Ловит stable (`v0.1.0`) и pre-release (`v0.1.0-rc.1`) теги.

## 5. Dockerfile

```dockerfile
# Build stage
FROM gradle:8.11-jdk21 AS build
WORKDIR /app

ARG APP_VERSION=0.0.1-SNAPSHOT

COPY build.gradle.kts settings.gradle.kts ./
COPY src ./src
RUN APP_VERSION=${APP_VERSION} gradle bootJar --no-daemon

# Runtime stage
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -g 1000 app && adduser -u 1000 -G app -D app
USER app

COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080

ENV JAVA_OPTS="-Xmx256m -Xms128m"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

## 6. build.gradle.kts

```kotlin
version = System.getenv("APP_VERSION") ?: "0.0.1-SNAPSHOT"

springBoot {
    buildInfo()
}
```

Версия берётся из env variable и доступна через `/actuator/info`.

## 7. Использование

### Pre-release (для тестирования в dev)

```bash
git tag v0.1.0-rc.1
git push origin v0.1.0-rc.1
```

### Stable release (для production)

```bash
git tag v0.1.0
git push origin v0.1.0
```

## Проверка

1. **GitHub Actions:** Repository → Actions → должен быть workflow "Release"
2. **Docker Hub:** https://hub.docker.com/r/USERNAME/REPO/tags

## Следующий шаг

[02. ArgoCD Image Updater](02-argocd-image-updater.md)
