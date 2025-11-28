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

## 2. Создание проекта

1. Dashboard → **+ Create Project**
2. Name: `example`
3. Автоматически создадутся environments: `dev`, `stg`, `prd`

## 3. Docker Hub Access Token

Перед добавлением секретов в Doppler, создай токен в Docker Hub:

1. https://hub.docker.com/settings/security
2. **New Access Token**
3. **Description:** `k8s-pull`
4. **Access permissions:** `Read-only` (только для pull образов)
5. **Generate** → скопируй токен (показывается один раз!)

> **Примечание:** Для push образов из CI/CD создадим отдельный токен с `Read & Write` в Фазе 4.

## 4. Добавление секретов в Doppler

Dashboard → Projects → `example` → `dev` → **Add Secret**:

| Key | Value | Описание |
|-----|-------|----------|
| `DOCKERHUB_USERNAME` | `shykhov` | Docker Hub username |
| `DOCKERHUB_PULL_TOKEN` | `dckr_pat_xxx...` | Read-only token |

После добавления секреты сохраняются автоматически.

## 5. Создание Service Token

Service Token нужен для доступа External Secrets Operator к Doppler:

1. Dashboard → Projects → `example` → `dev`
2. Вкладка **Access** (справа вверху)
3. **Service Tokens** → **+ Generate Service Token**
4. **Name:** `k8s-eso`
5. **Access:** `read`
6. **Generate**
7. **Скопируй токен** (`dp.st.dev.xxxx...`) — показывается только один раз!

> **Важно:** Сохрани токен — он понадобится для создания K8s Secret.

## Проверка

В Doppler UI:
- Projects → `example` → `dev`
- Видны секреты: `DOCKERHUB_USERNAME`, `DOCKERHUB_PULL_TOKEN`
- Access → Service Tokens → виден `k8s-eso`

## Структура секретов

```
Doppler Project: example
└── dev
    ├── DOCKERHUB_USERNAME      # Docker Hub username
    ├── DOCKERHUB_PULL_TOKEN    # Read-only token (для K8s pull)
    └── (позже) DOCKERHUB_PUSH_TOKEN  # Read & Write (для CI/CD, Фаза 4)
```

## Следующий шаг

[02. External Secrets Operator](02-external-secrets.md)
