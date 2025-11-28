# Phase 3: Doppler Setup

## Зачем

Doppler — централизованное хранилище секретов. External Secrets Operator будет синхронизировать секреты из Doppler в Kubernetes.

## 1. Регистрация

1. https://dashboard.doppler.com/register
2. Можно через GitHub
3. Developer план (бесплатный):
   - Unlimited projects
   - Unlimited secrets
   - 5 environments per project

## 2. Создание проекта и configs

1. Dashboard → **+ Create Project**
2. Name: `example`
3. Создать configs:
   - `shared` — общие секреты для всех environments (DockerHub и т.д.)
   - `dev` — app secrets для dev environment
   - `prd` — app secrets для prd environment (Phase 10)

## Архитектура configs

```
Doppler Project: example
├── config: shared  → общие secrets (DockerHub, API keys общие для всех env)
├── config: dev     → app secrets для dev environment
└── config: prd     → app secrets для prd environment
```

**Почему shared отдельно?**
- DockerHub credentials одинаковые для всех environments
- Избегаем дублирования секретов
- Один ClusterSecretStore `doppler-shared` для общих секретов

## 3. Docker Hub Access Token

Перед добавлением секретов в Doppler, создай токен в Docker Hub:

1. https://hub.docker.com/settings/security
2. **New Access Token**
3. **Description:** `k8s-pull`
4. **Access permissions:** `Read-only` (только для pull образов)
5. **Generate** → скопируй токен (показывается один раз!)

> **Примечание:** Для push образов из CI/CD создадим отдельный токен с `Read & Write` в Фазе 4.

## 4. Добавление секретов в Doppler

### Config: shared (общие секреты)

Dashboard → Projects → `example` → `shared` → **Add Secret**:

| Key | Value | Описание |
|-----|-------|----------|
| `DOCKERHUB_USERNAME` | `your-username` | Docker Hub username |
| `DOCKERHUB_PULL_TOKEN` | `dckr_pat_xxx...` | Read-only token |

### Config: dev (app secrets)

Dashboard → Projects → `example` → `dev` → **Add Secret**:

| Key | Value | Описание |
|-----|-------|----------|
| `DATABASE_URL` | `postgres://...` | (пример) DB connection |
| `API_KEY` | `xxx...` | (пример) App API key |

## 5. Создание Service Tokens

Для каждого config нужен отдельный Service Token:

### Для shared config:
1. Dashboard → Projects → `example` → `shared`
2. **Access** → **Service Tokens** → **+ Generate**
3. **Name:** `k8s-eso-shared`
4. **Generate** → скопируй (`dp.st.shared.xxxx...`)

### Для dev config:
1. Dashboard → Projects → `example` → `dev`
2. **Access** → **Service Tokens** → **+ Generate**
3. **Name:** `k8s-eso-dev`
4. **Generate** → скопируй (`dp.st.dev.xxxx...`)

> **Важно:** Сохрани токены — они понадобятся для создания K8s Secrets.

## Проверка

В Doppler UI:
- Projects → `example` → `shared` → видны: `DOCKERHUB_USERNAME`, `DOCKERHUB_PULL_TOKEN`
- Projects → `example` → `dev` → видны app secrets
- Access → Service Tokens → видны `k8s-eso-shared`, `k8s-eso-dev`

## Итоговая структура

```
Doppler Project: example
├── shared/
│   ├── DOCKERHUB_USERNAME
│   ├── DOCKERHUB_PULL_TOKEN
│   └── (позже) другие общие секреты
├── dev/
│   └── (app secrets для dev)
└── prd/ (Phase 10)
    └── (app secrets для prd)
```

## Следующий шаг

[02. External Secrets Operator](02-external-secrets.md)
