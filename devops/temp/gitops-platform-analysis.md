# ПОЛНЫЙ АНАЛИЗ GITOPS ПЛАТФОРМЫ

**Дата:** 2025-12-15 (updated)
**Анализируемые репозитории:**
- `example-monorepo/modules/deploy` (24 YAML файла)
- `example-monorepo/modules/infrastructure` (89 YAML файлов)
- `gitops-platform` (115 YAML файлов)

---

## EXECUTIVE SUMMARY

### Критические проблемы (требуют немедленного исправления)
1. **Hardcoded credentials** в values.yaml - Auth0, Tailscale, Cloudflare IDs
2. **PostgreSQL PRD с 1 instance** - нет High Availability
3. **AUTH0_DOMAIN dev значения** используются в production
4. **Рассинхронизация** между monorepo субмодулями и gitops-platform

### Оценка текущего состояния
| Критерий | Deploy | Infrastructure | Общая |
|----------|--------|---------------|-------|
| Структура | 7/10 | 8/10 | 7.5/10 |
| DRY принцип | 4/10 | 5/10 | 4.5/10 |
| Security | 3/10 | 3/10 | 3/10 |
| Best Practices | 5/10 | 6/10 | 5.5/10 |
| Документация | 3/10 | 4/10 | 3.5/10 |
| **ИТОГО** | **4.4/10** | **5.2/10** | **4.8/10** |

---

## ЧАСТЬ 1: ТЕКУЩАЯ АРХИТЕКТУРА

### 1.1 Структура репозиториев

```
gitops-platform/
├── deploy/                             # Application deployments (decentralized)
│   ├── databases/                      # Database manifests + Tailscale config
│   │   └── {service}/
│   │       ├── postgres/main.yaml      # CloudNativePG cluster + tailscale section
│   │       └── redis/cache.yaml        # Redis instance
│   ├── services/                       # Service Helm charts + Ingress config
│   │   ├── {service}/
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml             # Shared config
│   │   │   ├── values-dev.yaml         # DEV: ingress.tailscale.enabled
│   │   │   └── values-prd.yaml         # PRD: ingress.subdomain
│   └── _library/                       # Shared Helm library
│
├── infrastructure/                     # Platform infrastructure
│   ├── apps/                           # ArgoCD Applications (App-of-Apps)
│   │   ├── templates/
│   │   │   ├── cicd/                   # ArgoCD, Image Updater
│   │   │   ├── core/                   # Operators, Secrets
│   │   │   ├── data/                   # postgres-clusters, redis-clusters
│   │   │   ├── monitoring/             # Prometheus, Loki, Alloy
│   │   │   ├── network/                # Ingress, DNS, Tunnels, protected-services
│   │   │   └── services/               # services-appset (multi-source)
│   │   └── values.yaml
│   ├── bootstrap/root.yaml             # Entry point
│   ├── charts/
│   │   ├── protected-services/         # ONLY infra services (vault, argocd, longhorn, grafana)
│   │   ├── service-ingress/            # HTTP ingress for services (NGINX + Tailscale)
│   │   └── tailscale-service/          # TCP exposure for databases
│   ├── helm-values/                    # External chart values
│   └── manifests/                      # Raw Kubernetes manifests
│
├── docs/                               # Documentation
└── scripts/                            # Automation scripts
```

### 1.2 Компоненты инфраструктуры (25 компонентов)

| Wave | Компонент | Назначение | Статус |
|------|-----------|------------|--------|
| 0 | argocd-config | GitOps controller config | OK |
| 3 | longhorn | Distributed storage | OK |
| 4 | external-secrets | Secret management | OK |
| 5 | cloudnative-pg | PostgreSQL operator | OK |
| 5 | redis-operator | Redis operator (OT) | OK |
| 5 | credentials | ExternalSecrets from Doppler | OK |
| 5 | reloader | Auto-restart on config change | OK |
| 5 | secret-stores | ClusterSecretStore | OK |
| 7 | argocd-image-updater | Image auto-update | OK |
| 10 | postgres-clusters | CNPG clusters + Tailscale exposure | OK |
| 10 | redis-clusters | Dynamic Redis instances | OK |
| 10 | tailscale-operator | Private networking | OK |
| 12 | nginx-ingress | Ingress controller | OK |
| 13 | external-dns | DNS automation | OK |
| 15 | oauth2-proxy | OIDC auth proxy | OK |
| 17 | protected-services | Infra services only (vault, argocd, longhorn, grafana) | OK |
| 21 | cloudflare-tunnel | Public access | OK |
| 29 | node-tuning | Kernel params | OK |
| 30 | kube-prometheus-stack | Monitoring | OK |
| 32 | loki | Log aggregation | OK |
| 33 | alloy | Log collection | OK |
| 35 | prometheus-rules | Alerting | OK |
| 100 | services | App deployments + Ingress (multi-source) | OK |

### 1.3 Decentralized Ingress Architecture

Ingress и Tailscale конфигурация находится рядом с сервисами и базами данных в deploy репозитории.

#### Services (HTTP)

```
deploy/services/*/values-{env}.yaml     → ingress section
        │
        ▼
ApplicationSet (services-appset)
  └── sources:
        ├── Service Helm chart (Deployment, Service)
        └── service-ingress chart (NGINX + Tailscale Ingress)
              │
              ▼
        DEV: {service}-dev.{tailnet}.ts.net (Tailscale)
        PRD: {subdomain}.{domain} (Cloudflare)
```

**DEV конфигурация:**
```yaml
# deploy/services/{service}/values-dev.yaml
ingress:
  enabled: true
  tailscale:
    enabled: true
```

**PRD конфигурация:**
```yaml
# deploy/services/{service}/values-prd.yaml
ingress:
  enabled: true
  subdomain: api-{service}  # => api-{service}.gaynance.com
```

#### Databases (TCP)

```
deploy/databases/*/postgres/main.yaml   → tailscale section
        │
        ▼
ApplicationSet (postgres-clusters)
  └── sources:
        ├── CloudNativePG Cluster chart
        └── tailscale-service chart (LoadBalancer)
              │
              ▼
        {hostname}-{env}.{tailnet}.ts.net:5432
```

**Конфигурация:**
```yaml
# deploy/databases/{service}/postgres/main.yaml
cluster:
  instances: 1
  storage:
    size: 5Gi

tailscale:
  enabled: true
  hostname: {service}-db  # => {service}-db-{env}.ts.net:5432
```

#### Protected Services (Infrastructure Only)

```yaml
# infrastructure/charts/protected-services/values.yaml
services:
  vault:     # vault.ts.net (direct)
  argocd:    # argocd.ts.net
  longhorn:  # longhorn.ts.net
  grafana:   # grafana.ts.net
```

---

## ЧАСТЬ 2: НАЙДЕННЫЕ ПРОБЛЕМЫ

### 2.1 CRITICAL: Hardcoded Sensitive Values

**Файл:** `infrastructure/apps/values.yaml`

```yaml
global:
  tailnet: tail876052                    # Personal Tailscale tailnet
  tailscale:
    clientId: k3r7wuCSzd11CNTRL          # Client ID in Git!
  auth0:
    domain: dev-tgrsoxiakeqdr1gg.us.auth0.com
    clientId: wsZ3vIm5FlxztPisdo3Jq5BaeJvASZrz
  cloudflare:
    tunnelId: f6746974-5104-49ef-beed-c66a048f5062
  telegram:
    chatId: "-1003078665133"
  s3:
    endpoint: https://4aa95df965d3bc2bfaabe9012a35857c.r2.cloudflarestorage.com
```

**Почему это критично:**
- Account-specific данные в публичном репозитории
- Невозможно использовать для других окружений
- Нарушает принцип "конфиг как код без секретов"

**Решение:**
```yaml
global:
  tailnet: "" # Set via ExternalSecret or CI/CD
  tailscale:
    clientIdSecretRef:
      name: tailscale-credentials
      key: client-id
```

---

### 2.2 CRITICAL: AUTH0 Dev Values в Production

**Файл:** `deploy/services/example-api/values.yaml`

```yaml
env:
  - name: AUTH0_DOMAIN
    value: "dev-tgrsoxiakeqdr1gg.us.auth0.com"  # DEV in BASE file!
  - name: AUTH0_AUDIENCE
    value: "https://api.untrustedonline.org"
```

**Файл:** `deploy/services/example-api/values-prd.yaml`

```yaml
# AUTH0 НЕ ПЕРЕОПРЕДЕЛЕН!
# Production будет использовать DEV Auth0!
```

**Решение:** Переместить все env-specific значения в values-{env}.yaml

---

### 2.3 CRITICAL: PostgreSQL PRD = 1 Instance (No HA)

**Файл:** `infrastructure/helm-values/data/postgres-prd-defaults.yaml`

```yaml
cluster:
  instances: 1  # КРИТИЧНО: Нет HA для production!
  affinity:
    topologyKey: kubernetes.io/hostname  # Бесполезно с 1 instance
```

**Решение:**
```yaml
cluster:
  instances: 3  # Минимум для HA + quorum
  primaryUpdateStrategy: unsupervised
```

---

### 2.4 HIGH: Redis Sentinel с 2 Nodes (Quorum Issues)

**Файл:** `infrastructure/helm-values/data/redis-prd-defaults.yaml`

```yaml
mode: sentinel
clusterSize: 2  # Sentinel требует минимум 3 для quorum!
```

**Решение:**
```yaml
mode: sentinel
clusterSize: 3
sentinelSize: 3
```

---

### 2.5 HIGH: Дублирование S3 Endpoint (4+ мест)

**Найдено в файлах:**
- `apps/values.yaml:56`
- `helm-values/data/postgres-dev-defaults.yaml:42`
- `helm-values/data/postgres-prd-defaults.yaml:47`
- `helm-values/data/postgres-prd-defaults.yaml:83`

```yaml
endpointURL: https://4aa95df965d3bc2bfaabe9012a35857c.r2.cloudflarestorage.com
```

**Решение:** Централизовать в одном месте с ссылками

---

### 2.6 HIGH: Secret References Duplication

**Файл:** `deploy/services/example-api/values-dev.yaml`

```yaml
# Одно имя secret повторяется 3 раза:
- name: SPRING_DATASOURCE_URL
  valueFrom:
    secretKeyRef:
      name: example-api-main-db-dev-cluster-app  # 1
      key: jdbc-uri
- name: SPRING_DATASOURCE_USERNAME
  valueFrom:
    secretKeyRef:
      name: example-api-main-db-dev-cluster-app  # 2
      key: username
- name: SPRING_DATASOURCE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: example-api-main-db-dev-cluster-app  # 3
      key: password
```

---

### 2.7 MEDIUM: Sync-Wave Ordering Issues

```
Wave 29: node-tuning (комментарий: "must run before monitoring wave 29")
         ^^^^^^^^^^ ЭТО ТА ЖЕ ВОЛНА!

Wave 12: nginx-ingress (комментарий: "depends on tailscale wave 11")
         ^^^^^^^^^^ Wave 11 не существует!
```

---

### 2.8 MEDIUM: Redis Host Inconsistency

```yaml
# DEV
SPRING_DATA_REDIS_HOST: "example-api-cache-dev"       # без -master

# PRD
SPRING_DATA_REDIS_HOST: "example-api-cache-prd-master"  # с -master
```

Разные имена сервисов для разных режимов Redis (standalone vs sentinel).

---

### 2.9 LOW: Debug Logging в Production Config

**Файл:** `infrastructure/helm-values/network/external-dns.yaml`

```yaml
logLevel: debug  # Должно быть info или warning для production
```

---

### 2.10 LOW: Hardcoded Cluster Name

**Файл:** `infrastructure/helm-values/monitoring/alloy.yaml`

```yaml
cluster = "k3s-home"  # Hardcoded, не параметризовано
```

---

## ЧАСТЬ 3: РАССИНХРОНИЗАЦИЯ МЕЖДУ РЕПОЗИТОРИЯМИ

### 3.1 Deploy Module vs gitops-platform/deploy

| Файл | Статус |
|------|--------|
| services/example-api/values.yaml | DIFFERS |
| services/example-api/values-dev.yaml | DIFFERS |
| services/example-api/values-prd.yaml | DIFFERS |
| services/example-ui/values.yaml | DIFFERS |
| services/example-ui/values-dev.yaml | DIFFERS |
| services/example-ui/values-prd.yaml | DIFFERS |
| .argocd-source-*.yaml | ONLY IN MONOREPO |

### 3.2 Infrastructure Module vs gitops-platform/infrastructure

| Файл | Статус |
|------|--------|
| apps/values.yaml | DIFFERS |
| apps/templates/network/oauth2-proxy.yaml | DIFFERS |
| bootstrap/root.yaml | DIFFERS |
| charts/protected-services/values.yaml | DIFFERS |
| helm-values/network/external-dns.yaml | DIFFERS |
| manifests/apps/image-updater/*.yaml | DIFFERS |

### 3.3 Проблема двойного источника истины

Сейчас есть ДВА места хранения конфигурации:
1. `example-monorepo/modules/deploy` и `modules/infrastructure` (submodules)
2. `gitops-platform/deploy` и `infrastructure`

Это приводит к:
- Дрейфу конфигурации
- Непонятно что является source of truth
- Риск deploy неправильной версии

---

## ЧАСТЬ 4: РЕКОМЕНДУЕМАЯ АРХИТЕКТУРА

### 4.1 Целевая Структура (по FluxCD Best Practices)

```
gitops-platform/
├── apps/                               # Application deployments
│   ├── base/                           # Shared base configs
│   │   ├── example-api/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── release.yaml           # HelmRelease
│   │   │   └── repository.yaml        # HelmRepository
│   │   └── example-ui/
│   │       └── ...
│   ├── dev/                            # Dev environment overlays
│   │   ├── kustomization.yaml
│   │   └── patches/
│   │       ├── example-api-patch.yaml
│   │       └── example-ui-patch.yaml
│   └── prd/                            # Production overlays
│       ├── kustomization.yaml
│       └── patches/
│           └── ...
│
├── infrastructure/
│   ├── controllers/                    # Operators and CRDs
│   │   ├── cloudnative-pg.yaml
│   │   ├── external-secrets.yaml
│   │   ├── redis-operator.yaml
│   │   └── kustomization.yaml
│   ├── configs/                        # Configs that depend on controllers
│   │   ├── cluster-issuers.yaml
│   │   ├── secret-stores.yaml
│   │   └── kustomization.yaml
│   └── sources/                        # Helm repositories
│       └── kustomization.yaml
│
├── clusters/
│   ├── dev/
│   │   ├── flux-system/                # Flux bootstrap
│   │   ├── apps.yaml                   # Kustomization -> apps/dev
│   │   └── infrastructure.yaml         # Kustomization -> infrastructure
│   └── prd/
│       ├── flux-system/
│       ├── apps.yaml
│       └── infrastructure.yaml
│
├── charts/                             # Custom Helm charts
│   └── _library/
│
└── config/                             # Centralized configuration
    ├── base.yaml                       # Shared values
    ├── dev.yaml                        # Dev-specific
    └── prd.yaml                        # Prd-specific
```

### 4.2 Ключевые Изменения

1. **Удалить дублирование:**
   - Один source of truth (gitops-platform)
   - Субмодули в monorepo -> symbolic links или Git subtree

2. **Kustomize вместо Helm values:**
   - Base с общими настройками
   - Overlays для environment-specific patches
   - Централизованные patches

3. **Secrets через ExternalSecrets:**
   - Все sensitive values в Doppler
   - Только references в Git

4. **Порядок sync-wave:**
   ```
   Wave 0:   flux-system (bootstrap)
   Wave 1:   sources (HelmRepository, GitRepository)
   Wave 2:   external-secrets-operator
   Wave 3:   secret-stores (ClusterSecretStore)
   Wave 5:   storage (longhorn)
   Wave 10:  operators (cloudnative-pg, redis-operator)
   Wave 15:  credentials (ExternalSecrets)
   Wave 20:  data (postgres-clusters, redis-clusters)
   Wave 25:  network (nginx, external-dns)
   Wave 30:  auth (oauth2-proxy)
   Wave 35:  tunnels (tailscale, cloudflare)
   Wave 50:  monitoring (prometheus, loki, alloy)
   Wave 100: applications
   ```

---

## ЧАСТЬ 5: ПЛАН МИГРАЦИИ

### Фаза 1: Исправление Критических Проблем (1-2 дня)

1. **Вынести hardcoded values в Doppler:**
   - AUTH0_DOMAIN, AUTH0_CLIENT_ID
   - TAILSCALE_CLIENT_ID
   - CLOUDFLARE_TUNNEL_ID
   - S3_ENDPOINT

2. **Добавить AUTH0 override в values-prd.yaml:**
   ```yaml
   env:
     - name: AUTH0_DOMAIN
       value: "{{ .Values.auth0.domain }}"  # from ExternalSecret
   ```

3. **Увеличить PostgreSQL PRD instances:**
   ```yaml
   cluster:
     instances: 3
   ```

4. **Увеличить Redis PRD clusterSize:**
   ```yaml
   clusterSize: 3
   ```

### Фаза 2: Консолидация Репозиториев (2-3 дня)

1. **Определить source of truth:**
   - gitops-platform = единственный источник
   - Субмодули = deprecated, только для CI/CD build

2. **Синхронизировать все файлы:**
   ```bash
   # Взять последнюю версию из submodules
   cp -r modules/deploy/* gitops-platform/deploy/
   cp -r modules/infrastructure/* gitops-platform/infrastructure/
   ```

3. **Удалить дубликаты:**
   - Убрать .argocd-source-*.yaml если не используются
   - Унифицировать values структуру

### Фаза 3: Рефакторинг Структуры (3-5 дней)

1. **Внедрить Kustomize overlays:**
   - Создать base/ для каждого сервиса
   - Создать overlays/dev и overlays/prd

2. **Централизовать конфигурацию:**
   - Создать config/base.yaml с общими значениями
   - Убрать дублирование S3 endpoint

3. **Исправить sync-wave ordering:**
   - node-tuning -> wave 2
   - nginx-ingress -> wave 25

### Фаза 4: Документация и Валидация (1-2 дня)

1. **Добавить values.schema.json для Helm charts**
2. **Добавить pre-commit hooks для validation**
3. **Документировать архитектуру в README**

---

## ЧАСТЬ 6: ЧЕКЛИСТ ИСПРАВЛЕНИЙ

### Critical (Блокирующие)
- [ ] Вынести AUTH0/Tailscale/Cloudflare IDs в Doppler
- [ ] Добавить AUTH0 override в values-prd.yaml для example-api
- [ ] Увеличить PostgreSQL PRD instances до 3
- [ ] Увеличить Redis PRD clusterSize до 3
- [ ] Синхронизировать monorepo submodules с gitops-platform

### High Priority
- [ ] Централизовать S3 endpoint (убрать 4 дубликата)
- [ ] Параметризовать secret references (database.secretName)
- [ ] Исправить node-tuning sync-wave (29 -> 2)
- [ ] Изменить external-dns logLevel (debug -> info)

### Medium Priority
- [ ] Добавить комментарии о Redis host разнице (dev vs prd)
- [ ] Параметризовать Alloy cluster name
- [ ] Добавить Loki environment-specific retention
- [ ] Документировать .argocd-source файлы

### Low Priority
- [ ] Добавить values.schema.json
- [ ] Синхронизировать Chart версии (0.2.0 vs 0.1.0)
- [ ] Добавить serviceMonitor для ArgoCD, External-DNS
- [ ] Создать ARCHITECTURE.md

---

## ИСТОЧНИКИ

### Официальная документация
- [FluxCD Repository Structure](https://fluxcd.io/flux/guides/repository-structure/)
- [FluxCD Kustomize Best Practices](https://fluxcd.io/flux/components/kustomize/)
- [Kustomize Components](https://kubernetes-sigs.github.io/kustomize/api-reference/kustomization/components/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)

### Примеры репозиториев
- [flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
- [flux2-multi-tenancy](https://github.com/fluxcd/flux2-multi-tenancy)

### Best Practices References
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [CloudNativePG HA Configuration](https://cloudnative-pg.io/documentation/current/replication/)
- [Redis Sentinel Quorum](https://redis.io/docs/management/sentinel/)
