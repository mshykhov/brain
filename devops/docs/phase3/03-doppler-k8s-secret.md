# Phase 3: Doppler Service Token → K8s Secret

## Зачем

Это **единственные секреты**, которые создаются вручную. Они нужны для того, чтобы External Secrets Operator мог аутентифицироваться в Doppler и синхронизировать остальные секреты.

## Архитектура секретов

```
Doppler Project: example
├── config: dev     → app secrets для dev environment
├── config: prd     → app secrets для prd environment
└── config: shared  → общие secrets (DockerHub и т.д.)
```

Каждый Doppler config требует свой Service Token и K8s Secret.

## Naming Convention

| Doppler Config | K8s Secret | ClusterSecretStore | Назначение |
|----------------|------------|-------------------|------------|
| `shared` | `doppler-token-shared` | `doppler-shared` | Общие секреты (DockerHub) |
| `dev` | `doppler-token-dev` | `doppler-dev` | App secrets для dev |
| `prd` | `doppler-token-prd` | `doppler-prd` | App secrets для prd |

## Создание секретов

### 1. Shared (общие секреты)

Для DockerHub credentials и других общих секретов:

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic doppler-token-shared \
    --namespace external-secrets \
    --from-literal=dopplerToken="dp.st.shared.XXXX"
```

### 2. Dev environment

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic doppler-token-dev \
    --namespace external-secrets \
    --from-literal=dopplerToken="dp.st.dev.XXXX"
```

### 3. Prd environment (Phase 10)

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic doppler-token-prd \
    --namespace external-secrets \
    --from-literal=dopplerToken="dp.st.prd.XXXX"
```

> **Примечание:** `HISTIGNORE` предотвращает сохранение команды с токеном в bash history.

## Где взять токен

1. Doppler Dashboard → project `example` → config (`shared`/`dev`/`prd`)
2. Access tab → Service Tokens → Generate
3. Скопировать токен (показывается только один раз!)

## Почему в namespace external-secrets

ClusterSecretStore ссылается на эти секреты. Для ClusterSecretStore нужно явно указать namespace — логично держать все токены рядом с ESO.

## Проверка

```bash
# Все секреты созданы
kubectl get secrets -n external-secrets | grep doppler-token

# Детали конкретного секрета
kubectl describe secret doppler-token-shared -n external-secrets
```

Ожидаемый вывод:
```
NAME                   TYPE     DATA   AGE
doppler-token-shared   Opaque   1      1m
doppler-token-dev      Opaque   1      5m
```

## Следующий шаг

[ClusterSecretStore](04-cluster-secret-store.md)
