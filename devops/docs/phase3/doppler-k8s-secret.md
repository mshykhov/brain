# Phase 3: Doppler Service Token → K8s Secret

## Зачем

Это **единственный секрет**, который создаётся вручную (на каждый environment). Он нужен для того, чтобы External Secrets Operator мог аутентифицироваться в Doppler и синхронизировать остальные секреты.

## Naming Convention

Для multi-environment используем суффикс `-dev`, `-stg`, `-prd`:

| Environment | Secret Name | ClusterSecretStore |
|-------------|-------------|-------------------|
| dev | `doppler-token-dev` | `doppler-dev` |
| prd | `doppler-token-prd` | `doppler-prd` |

## Создание секрета (dev)

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic doppler-token-dev \
    --namespace external-secrets \
    --from-literal=dopplerToken="dp.st.dev.XXXX"
```

Замени `dp.st.dev.XXXX` на Service Token из Doppler (project: `example`, config: `dev`).

> **Примечание:** `HISTIGNORE` предотвращает сохранение команды с токеном в bash history.

## Почему в namespace external-secrets

ClusterSecretStore будет ссылаться на этот секрет. Для ClusterSecretStore нужно явно указать namespace где лежит секрет — логично держать все токены рядом с ESO.

## Проверка

```bash
# Секрет создан
kubectl get secret doppler-token-dev -n external-secrets

# Детали (без значения)
kubectl describe secret doppler-token-dev -n external-secrets
```

Ожидаемый вывод:
```
Name:         doppler-token-dev
Namespace:    external-secrets
Type:         Opaque

Data
====
dopplerToken:  XX bytes
```

## Добавление других environments

Для `prd` (Phase 10):
1. Создать Service Token в Doppler (project: `example`, config: `prd`)
2. Создать секрет:
```bash
HISTIGNORE='*kubectl*' kubectl create secret generic doppler-token-prd \
    --namespace external-secrets \
    --from-literal=dopplerToken="dp.st.prd.XXXX"
```

## Следующий шаг

[ClusterSecretStore](cluster-secret-store.md)
