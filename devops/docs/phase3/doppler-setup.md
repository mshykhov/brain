# Phase 3: Doppler Setup

## Зачем

Doppler — централизованное хранилище секретов. External Secrets Operator будет синхронизировать секреты из Doppler в Kubernetes.

## Регистрация

1. https://dashboard.doppler.com/register
2. Developer план (бесплатный)

## Создание проекта

1. Dashboard → **+ Create Project**
2. Name: `example`
3. Автоматически создадутся environments: `dev`, `stg`, `prd`

## Создание секретов в dev

Dashboard → Projects → `example` → `dev` → **Add Secret**:

| Key | Value | Описание |
|-----|-------|----------|
| `DOCKER_USERNAME` | `shykhov` | Docker Hub username |
| `DOCKER_PASSWORD` | `<token>` | Docker Hub access token |

> **Важно:** Для Docker Hub лучше использовать Access Token вместо пароля.
> Docker Hub → Account Settings → Security → New Access Token

## Service Token

Для доступа ESO к Doppler нужен Service Token:

1. Dashboard → Projects → `example` → `dev`
2. **Access** tab → **Service Tokens** → **Generate**
3. Name: `k8s-eso`
4. Access: `read`
5. **Сохрани токен** — он понадобится для K8s Secret

## Проверка

```bash
# Проверить доступ (опционально, если установлен Doppler CLI)
doppler secrets --project example --config dev
```

## Следующий шаг

[External Secrets Operator](external-secrets.md)
