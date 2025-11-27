# GitOps Infrastructure Architecture v5

> Дата: 2024-11-27
> Статус: Production-Ready Blueprint (Complete)
> Цель: Полная архитектура с нуля для self-hosted Kubernetes

---

## Изменения относительно v4

| Компонент | v4 | v5 |
|-----------|----|----|
| ESO/Doppler | Ошибки в конфигурации | Исправлено, добавлен project/config |
| MetalLB | Только установка | Полная конфигурация с IPAddressPool |
| Promtail | Отсутствует | Добавлена полная конфигурация |
| Library Chart | Неполный | Добавлен _helpers.tpl |
| PostgreSQL | Только упомянут | CloudNativePG с примерами |
| Kafka | Только упомянут | Strimzi с конфигурацией |
| GitOps Auth | Отсутствует | SSH keys, Docker Registry |
| Alertmanager | Только упомянут | Полный template для Telegram |
| Tailscale | Pod-based subnet router | Connector CRD (нативный способ) |
| Image Updater | CRD пример | Исправлен + fallback на annotations |

---

## Масштаб проекта

> **ВАЖНО:** Данная архитектура оптимизирована для небольшого проекта:
> - **Пользователи приложения:** < 100 активных пользователей
> - **Команда разработки:** 1-3 человека
> - **Сервисы:** 10-20 микросервисов
> - **Данные:** Большой объём логов, метрик и исторических данных (trading data)
> - **Бюджет:** Минимальный (предпочтение free tier решениям)

### Характеристика нагрузки

| Параметр | Значение | Комментарий |
|----------|----------|-------------|
| Пользователи | < 100 | Мало, но критичны |
| Данные | 50-100 GB/день | Логи, метрики, market data |
| Retention | 30-90 дней | Нужна история для анализа |
| Доступность | 99% | Важно, но не критично |

Это влияет на выбор инструментов:
- **SaaS для auth/secrets** — мало пользователей, free tier покрывает
- **Self-hosted для данных** — много данных, облако будет дорого
- **Loki вместо ELK** — эффективнее для большого объёма логов
- **Longhorn** — простота важнее производительности для нашего масштаба

---

## Ключевые принципы

1. **Self-hosted где возможно** — минимизация зависимости от облаков
2. **SaaS где оправдано** — Auth0, Doppler (free tier покрывает наши потребности)
3. **Open-source preferred** — MIT/Apache/MPL для core инфраструктуры
4. **Простота** — минимум компонентов для решения задачи
5. **Гибкость** — поддержка sidecar-контейнеров, изолированных сервисов

---

## Архитектура репозиториев

**Официальная рекомендация ArgoCD:**
> "Using a separate Git repository to hold your Kubernetes manifests, keeping the config separate from your application source code, is highly recommended"
> — [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)

### Схема

```
┌─────────────────────────────────────────────────────────────────┐
│  mg-central (Source Code)                                       │
│  • services/, frontend/, libs/                                  │
│  • Dockerfile для каждого сервиса                              │
│  • CI: build → test → push Docker image                        │
│  НЕ содержит: Helm charts, K8s manifests                       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ Docker Image → Registry
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  mg-deploy (Application Config)                                 │
│  • _library/ — shared Helm library chart                       │
│  • services/{name}/ — Helm chart для каждого сервиса           │
│  • databases/ — PostgreSQL deployments                          │
│  Обновляется: ArgoCD Image Updater автоматически               │
└──────────────────────────┬──────────────────────────────────────┘
                           │ ArgoCD sync
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  mg-infrastructure (Platform)                                   │
│  • bootstrap/ — App-of-Apps точка входа                        │
│  • applicationsets/ — автогенерация Applications               │
│  • base/ — infrastructure components (ArgoCD, Traefik, etc.)   │
│  • image-updaters/ — ImageUpdater CRDs                         │
└─────────────────────────────────────────────────────────────────┘
```

### Почему 3 репозитория

| Причина | Описание |
|---------|----------|
| Разделение циклов | Изменение replicas ≠ пересборка приложения |
| Audit log | Чистая история config без dev коммитов |
| CI loops | Image Updater коммитит в отдельный repo |
| Доступ | Developers ≠ production config access |

---

## Secret Management

**Официальная позиция ArgoCD:**
> "We strongly recommend destination cluster secret management... Argo CD does not need to have access to the secrets"
> — [ArgoCD Secret Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)

### Выбор: External Secrets Operator + Doppler

**Почему такая связка:**
- **ESO** — Kubernetes-native, vendor-neutral, CNCF проект
- **Doppler** — отличный UI, простота, free tier покрывает наши потребности
- **Гибкость** — можно мигрировать на другой provider (Vault, AWS SM) без изменения K8s манифестов

| Критерий | Doppler Developer (Free) |
|----------|--------------------------|
| Users | 3 (достаточно для нашей команды) |
| Projects | Unlimited |
| Environments | Unlimited |
| Secrets | Unlimited |
| Activity Logs | 3 дня |

### Установка

```bash
# External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set installCRDs=true

# Doppler Service Token (создаётся вручную в Doppler UI)
# Project Settings → Service Tokens → Generate
kubectl create secret generic doppler-token \
  -n external-secrets \
  --from-literal=dopplerToken=dp.st.xxxx
```

### ClusterSecretStore (один на кластер)

```yaml
# mg-infrastructure/base/external-secrets/cluster-secret-store.yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: doppler-production
spec:
  provider:
    doppler:
      project: mg-central      # Doppler project name
      config: production       # Environment: dev/staging/production
      auth:
        secretRef:
          dopplerToken:
            name: doppler-token
            namespace: external-secrets
            key: dopplerToken
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: doppler-development
spec:
  provider:
    doppler:
      project: mg-central
      config: development
      auth:
        secretRef:
          dopplerToken:
            name: doppler-token
            namespace: external-secrets
            key: dopplerToken
```

### ExternalSecret (для каждого сервиса)

```yaml
# mg-deploy/services/engine/templates/external-secret.yaml
{{- if .Values.externalSecret.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-{{ .Values.environment }}
  target:
    name: {{ include "mg.fullname" . }}-secrets
    creationPolicy: Owner
  data:
    {{- range .Values.externalSecret.keys }}
    - secretKey: {{ .secretKey }}
      remoteRef:
        key: {{ .remoteKey }}
    {{- end }}
{{- end }}
```

### Пример values.yaml для ExternalSecret

```yaml
# mg-deploy/services/engine/values.yaml
environment: production  # Выбирает ClusterSecretStore

externalSecret:
  enabled: true
  keys:
    - secretKey: DB_PASSWORD
      remoteKey: ENGINE_DB_PASSWORD
    - secretKey: KAFKA_PASSWORD
      remoteKey: KAFKA_PASSWORD
    - secretKey: API_KEY
      remoteKey: ENGINE_API_KEY
```

### Структура в Doppler

```
Project: mg-central
├── development
│   ├── ENGINE_DB_PASSWORD
│   ├── BROKER_API_KEY_BINANCE
│   ├── KAFKA_PASSWORD
│   └── ...
├── staging
│   └── ...
└── production
    └── ...
```

### Upgrade path (если вырастем)

| Текущий масштаб | Решение |
|-----------------|---------|
| < 3 users | Doppler Developer (Free) |
| 3-10 users | Doppler Team ($8/user/month) |
| Self-hosted требование | Infisical (MIT, self-hosted) |
| Enterprise | HashiCorp Vault / AWS Secrets Manager |

---

## Authentication

### Выбор: Auth0 (SaaS)

**Почему Auth0, а не Keycloak:**

| Критерий | Auth0 | Keycloak |
|----------|-------|----------|
| Setup time | 30 минут | 2-3 дня |
| Maintenance | Zero | Постоянный |
| Free tier | 7,500 MAU | Бесплатно, но DevOps overhead |
| Документация | Отличная | Хорошая |
| SSO, Social login | Из коробки | Настройка вручную |

**Для нашего масштаба (< 100 users):**
- Auth0 Free tier покрывает потребности с запасом (7,500 MAU)
- Нет смысла тратить время на настройку и поддержку Keycloak
- Keycloak = overkill для небольшого проекта

### Интеграция с Kubernetes

```yaml
# Traefik ForwardAuth middleware
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: auth0-auth
  namespace: traefik
spec:
  forwardAuth:
    address: http://auth-service.default.svc:8080/verify
    trustForwardHeader: true
    authResponseHeaders:
      - X-User-Id
      - X-User-Email
      - X-User-Roles
---
# IngressRoute с аутентификацией
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: frontend
  namespace: frontend
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`app.example.com`)
      kind: Rule
      middlewares:
        - name: auth0-auth
          namespace: traefik
      services:
        - name: frontend
          port: 80
  tls:
    certResolver: letsencrypt
```

### Upgrade path

| Масштаб | Решение |
|---------|---------|
| < 7,500 MAU | Auth0 Free |
| < 10,000 MAU | Auth0 Essential ($35/month) |
| > 10,000 MAU или self-hosted требование | Keycloak |

---

## Network Security — Tailscale

### Зачем нужен Tailscale

Tailscale обеспечивает **zero-trust доступ** к инфраструктуре:
- Доступ к Grafana, ArgoCD, Prometheus **без публичного IP**
- Прямой доступ к подам (`kubectl exec`, port-forward) **из любой точки**
- Безопасный SSH к нодам кластера
- Mesh-сеть между разработчиками и инфраструктурой

### Выбор плана: Personal (FREE)

**Важно:** Tailscale различает Personal и Business использование:

| Регистрация через | Тип | Цена |
|-------------------|-----|------|
| Gmail, GitHub (personal) | Personal | **$0** |
| Custom domain (company.com) | Business | $6/user/month |

> **Для нашего масштаба (1-3 человека):** Регистрируемся через **Gmail или personal GitHub** → получаем Personal план бесплатно.

### Personal Plan — что включено

| Функция | Лимит | Наши потребности |
|---------|-------|------------------|
| Users | 3 | ✅ Достаточно |
| Devices | 100 | ✅ Хватит на все ноды + pods |
| Kubernetes Operator | ✅ Да | Нужен |
| Subnet routers | ✅ Да | Нужен |
| Tailscale SSH | ✅ Да | Удобно |
| ACL (access control) | ✅ Да | Базовый |
| MagicDNS | ✅ Да | Удобно |
| Service accounts | ✅ Да | Для K8s operator |

### Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                        TAILSCALE MESH                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │  Developer  │     │  Developer  │     │   CI/CD     │       │
│  │   Laptop    │     │   Phone     │     │   Runner    │       │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘       │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             │                                   │
│                    ┌────────▼────────┐                         │
│                    │   Tailscale     │                         │
│                    │   Coordinator   │                         │
│                    │   (SaaS)        │                         │
│                    └────────┬────────┘                         │
│                             │                                   │
│         ┌───────────────────┼───────────────────┐               │
│         │                   │                   │               │
│  ┌──────▼──────┐     ┌──────▼──────┐     ┌──────▼──────┐       │
│  │  K8s Node   │     │  K8s Node   │     │  K8s Node   │       │
│  │  (operator) │     │  (operator) │     │  (operator) │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│                                                                 │
│  Внутри кластера доступны:                                     │
│  • grafana.tailnet-xxxx.ts.net                                 │
│  • argocd.tailnet-xxxx.ts.net                                  │
│  • prometheus.tailnet-xxxx.ts.net                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Установка Tailscale Operator

```bash
# 1. Создать OAuth client в Tailscale Admin Console
#    Settings → OAuth clients → Generate
#    Scopes: devices, routes, dns

# 2. Установить operator
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  -n tailscale --create-namespace \
  --set oauth.clientId="${TS_CLIENT_ID}" \
  --set oauth.clientSecret="${TS_CLIENT_SECRET}" \
  --set operatorConfig.hostname="k8s-operator" \
  --wait
```

### Expose сервисов через Tailscale — Ingress (рекомендуется)

```yaml
# mg-infrastructure/base/tailscale/ingress-grafana.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-tailscale
  namespace: monitoring
  annotations:
    tailscale.com/tags: "tag:k8s-infra"
spec:
  ingressClassName: tailscale
  rules:
    - host: grafana  # Будет доступен как grafana.tailnet-xxxx.ts.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-grafana
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-tailscale
  namespace: argocd
  annotations:
    tailscale.com/tags: "tag:k8s-infra"
spec:
  ingressClassName: tailscale
  rules:
    - host: argocd
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-tailscale
  namespace: monitoring
  annotations:
    tailscale.com/tags: "tag:k8s-infra"
spec:
  ingressClassName: tailscale
  rules:
    - host: prometheus
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: kube-prometheus-stack-prometheus
                port:
                  number: 9090
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-tailscale
  namespace: longhorn-system
  annotations:
    tailscale.com/tags: "tag:k8s-infra"
spec:
  ingressClassName: tailscale
  rules:
    - host: longhorn
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: longhorn-frontend
                port:
                  number: 80
```

### Connector для Subnet Routing (нативный способ)

```yaml
# mg-infrastructure/base/tailscale/connector.yaml
apiVersion: tailscale.com/v1alpha1
kind: Connector
metadata:
  name: k8s-subnet-router
  namespace: tailscale
spec:
  hostname: k8s-subnet
  tags:
    - tag:k8s
  subnetRouter:
    advertiseRoutes:
      - 10.42.0.0/16   # Pod CIDR (k3s default)
      - 10.43.0.0/16   # Service CIDR (k3s default)
```

### ACL конфигурация

```json
// В Tailscale Admin Console → Access Controls
{
  "tagOwners": {
    "tag:k8s": ["autogroup:admin"],
    "tag:k8s-infra": ["autogroup:admin"]
  },
  "acls": [
    // Разработчики могут всё в tailnet
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["*:*"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:k8s"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

### Что expose через Tailscale

| Сервис | Hostname | Порт | Зачем |
|--------|----------|------|-------|
| Grafana | `grafana` | 80 | Мониторинг и дашборды |
| ArgoCD | `argocd` | 80 | GitOps UI |
| Prometheus | `prometheus` | 9090 | Метрики напрямую |
| Alertmanager | `alertmanager` | 9093 | Управление алертами |
| Longhorn UI | `longhorn` | 80 | Storage management |
| MinIO Console | `minio` | 9001 | S3 management |

---

## MetalLB — LoadBalancer для Bare-Metal

### Установка

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s
```

### Конфигурация IPAddressPool

```yaml
# mg-infrastructure/base/metallb/config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    # Диапазон IP из вашей локальной сети (пример для 192.168.1.x)
    - 192.168.1.240-192.168.1.250
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
  # Опционально: ограничить интерфейсы
  # interfaces:
  #   - eth0
```

### Для VPS/Cloud с одним IP

```yaml
# Если у вас один публичный IP на ноде
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: single-ip-pool
  namespace: metallb-system
spec:
  addresses:
    - 203.0.113.10/32  # Ваш публичный IP
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: single-ip
  namespace: metallb-system
spec:
  ipAddressPools:
    - single-ip-pool
```

---

## Структура mg-deploy

```
mg-deploy/
├── _library/                    # Shared Helm Library Chart
│   ├── Chart.yaml              # type: library
│   └── templates/
│       ├── _helpers.tpl        # labels, names, selectors
│       ├── _deployment.tpl     # базовый Deployment
│       ├── _service.tpl
│       ├── _ingress.tpl
│       ├── _hpa.tpl            # Horizontal Pod Autoscaler
│       ├── _external-secret.tpl
│       ├── _service-monitor.tpl
│       ├── _network-policy.tpl
│       └── _pdb.tpl            # PodDisruptionBudget
│
├── services/
│   ├── engine/
│   │   ├── Chart.yaml          # dependencies: [mg-library]
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── deployment.yaml # {{ include "mg.deployment" . }}
│   │       ├── service.yaml
│   │       └── external-secret.yaml
│   │
│   ├── broker/                 # Пример: сервис с sidecar
│   │   ├── values.yaml         # sidecars: [ccxt-proxy]
│   │   └── ...
│   │
│   └── {service}/
│
└── databases/
    ├── postgres-engine/
    └── postgres-broker/
```

### Library Chart — Chart.yaml

```yaml
# mg-deploy/_library/Chart.yaml
apiVersion: v2
name: mg-library
description: Shared Helm library chart for MG services
type: library
version: 1.0.0
```

### Library Chart — _helpers.tpl (ПОЛНЫЙ)

```yaml
# mg-deploy/_library/templates/_helpers.tpl

{{/*
Expand the name of the chart.
*/}}
{{- define "mg.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mg.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mg.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "mg.labels" -}}
helm.sh/chart: {{ include "mg.chart" . }}
{{ include "mg.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: mg-central
{{- end }}

{{/*
Selector labels
*/}}
{{- define "mg.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mg.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "mg.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mg.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "mg.image" -}}
{{- $registryName := .Values.image.registry | default "" -}}
{{- $repositoryName := .Values.image.repository -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion | toString -}}
{{- if $registryName }}
{{- printf "%s/%s:%s" $registryName $repositoryName $tag -}}
{{- else }}
{{- printf "%s:%s" $repositoryName $tag -}}
{{- end }}
{{- end }}

{{/*
Create image pull secrets
*/}}
{{- define "mg.imagePullSecrets" -}}
{{- if .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.global.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- else if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ . }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Environment name for secrets
*/}}
{{- define "mg.environment" -}}
{{- .Values.environment | default "development" }}
{{- end }}
```

### Library Chart — _deployment.tpl (ПОЛНЫЙ)

```yaml
# mg-deploy/_library/templates/_deployment.tpl

{{- define "mg.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
  {{- with .Values.deploymentAnnotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount | default 1 }}
  {{- end }}
  selector:
    matchLabels: {{- include "mg.selectorLabels" . | nindent 6 }}
  {{- with .Values.strategy }}
  strategy: {{- toYaml . | nindent 4 }}
  {{- end }}
  template:
    metadata:
      labels: {{- include "mg.selectorLabels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      annotations:
        {{- if .Values.externalSecret.enabled }}
        checksum/external-secret: {{ include "mg.fullname" . | sha256sum }}
        {{- end }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- include "mg.imagePullSecrets" . | nindent 6 }}
      serviceAccountName: {{ include "mg.serviceAccountName" . }}
      {{- with .Values.podSecurityContext }}
      securityContext: {{- toYaml . | nindent 8 }}
      {{- else }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      {{- end }}

      {{- with .Values.initContainers }}
      initContainers: {{- toYaml . | nindent 8 }}
      {{- end }}

      containers:
        - name: {{ .Chart.Name }}
          image: {{ include "mg.image" . }}
          imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
          {{- with .Values.securityContext }}
          securityContext: {{- toYaml . | nindent 12 }}
          {{- else }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          {{- end }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port | default 8080 }}
              protocol: TCP
            {{- range .Values.extraPorts }}
            - name: {{ .name }}
              containerPort: {{ .containerPort }}
              protocol: {{ .protocol | default "TCP" }}
            {{- end }}

          {{- if .Values.probes.liveness.enabled }}
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.liveness.path | default "/actuator/health/liveness" }}
              port: http
            initialDelaySeconds: {{ .Values.probes.liveness.initialDelaySeconds | default 30 }}
            periodSeconds: {{ .Values.probes.liveness.periodSeconds | default 10 }}
            timeoutSeconds: {{ .Values.probes.liveness.timeoutSeconds | default 5 }}
            failureThreshold: {{ .Values.probes.liveness.failureThreshold | default 3 }}
          {{- end }}

          {{- if .Values.probes.readiness.enabled }}
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.readiness.path | default "/actuator/health/readiness" }}
              port: http
            initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds | default 5 }}
            periodSeconds: {{ .Values.probes.readiness.periodSeconds | default 5 }}
            timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds | default 3 }}
            failureThreshold: {{ .Values.probes.readiness.failureThreshold | default 3 }}
          {{- end }}

          {{- if .Values.probes.startup.enabled }}
          startupProbe:
            httpGet:
              path: {{ .Values.probes.startup.path | default "/actuator/health/liveness" }}
              port: http
            initialDelaySeconds: {{ .Values.probes.startup.initialDelaySeconds | default 10 }}
            periodSeconds: {{ .Values.probes.startup.periodSeconds | default 10 }}
            timeoutSeconds: {{ .Values.probes.startup.timeoutSeconds | default 5 }}
            failureThreshold: {{ .Values.probes.startup.failureThreshold | default 30 }}
          {{- end }}

          resources: {{- toYaml .Values.resources | nindent 12 }}

          env:
            - name: SPRING_PROFILES_ACTIVE
              value: {{ .Values.springProfile | default "kubernetes" | quote }}
            {{- with .Values.env }}
            {{- toYaml . | nindent 12 }}
            {{- end }}

          {{- if .Values.externalSecret.enabled }}
          envFrom:
            - secretRef:
                name: {{ include "mg.fullname" . }}-secrets
          {{- end }}

          {{- with .Values.volumeMounts }}
          volumeMounts: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- if .Values.tmpDir.enabled }}
            - name: tmp
              mountPath: /tmp
          {{- end }}

        # Sidecar контейнеры
        {{- range .Values.sidecars }}
        - name: {{ .name }}
          image: {{ .image }}
          {{- with .securityContext }}
          securityContext: {{- toYaml . | nindent 12 }}
          {{- else }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          {{- end }}
          {{- with .ports }}
          ports: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .env }}
          env: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .resources }}
          resources: {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .volumeMounts }}
          volumeMounts: {{- toYaml . | nindent 12 }}
          {{- end }}
        {{- end }}

      volumes:
        {{- if .Values.tmpDir.enabled }}
        - name: tmp
          emptyDir:
            sizeLimit: {{ .Values.tmpDir.sizeLimit | default "100Mi" }}
        {{- end }}
        {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}

      {{- with .Values.nodeSelector }}
      nodeSelector: {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations: {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity: {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.topologySpreadConstraints }}
      topologySpreadConstraints: {{- toYaml . | nindent 8 }}
      {{- end }}
{{- end }}
```

### Library Chart — _service.tpl

```yaml
# mg-deploy/_library/templates/_service.tpl

{{- define "mg.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations: {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
    - name: http
      port: {{ .Values.service.port | default 8080 }}
      targetPort: http
      protocol: TCP
    {{- range .Values.service.extraPorts }}
    - name: {{ .name }}
      port: {{ .port }}
      targetPort: {{ .targetPort | default .name }}
      protocol: {{ .protocol | default "TCP" }}
    {{- end }}
  selector: {{- include "mg.selectorLabels" . | nindent 4 }}
{{- end }}
```

### Library Chart — _hpa.tpl

```yaml
# mg-deploy/_library/templates/_hpa.tpl

{{- define "mg.hpa" -}}
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "mg.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas | default 1 }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas | default 3 }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
  {{- with .Values.autoscaling.behavior }}
  behavior: {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
{{- end }}
```

### Library Chart — _pdb.tpl

```yaml
# mg-deploy/_library/templates/_pdb.tpl

{{- define "mg.pdb" -}}
{{- if .Values.pdb.enabled }}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
spec:
  {{- if .Values.pdb.minAvailable }}
  minAvailable: {{ .Values.pdb.minAvailable }}
  {{- else if .Values.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.pdb.maxUnavailable }}
  {{- else }}
  maxUnavailable: 1
  {{- end }}
  selector:
    matchLabels: {{- include "mg.selectorLabels" . | nindent 6 }}
{{- end }}
{{- end }}
```

### Library Chart — _network-policy.tpl

```yaml
# mg-deploy/_library/templates/_network-policy.tpl

{{- define "mg.networkPolicy" -}}
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels: {{- include "mg.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from same namespace
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: {{ .Values.service.port | default 8080 }}
    # Allow from Traefik ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: traefik
      ports:
        - protocol: TCP
          port: {{ .Values.service.port | default 8080 }}
    # Allow from monitoring (Prometheus scrape)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: {{ .Values.service.port | default 8080 }}
    {{- with .Values.networkPolicy.extraIngress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  egress:
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    # Allow to Kafka
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kafka
      ports:
        - protocol: TCP
          port: 9092
        - protocol: TCP
          port: 9093
    # Allow to databases
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: databases
      ports:
        - protocol: TCP
          port: 5432
    # Allow external HTTPS (for exchange APIs)
    {{- if .Values.networkPolicy.allowExternalHTTPS }}
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - protocol: TCP
          port: 443
    {{- end }}
    {{- with .Values.networkPolicy.extraEgress }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}
```

### Library Chart — _service-monitor.tpl

```yaml
# mg-deploy/_library/templates/_service-monitor.tpl

{{- define "mg.serviceMonitor" -}}
{{- if .Values.metrics.enabled }}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels: {{- include "mg.selectorLabels" . | nindent 6 }}
  namespaceSelector:
    matchNames:
      - {{ .Release.Namespace }}
  endpoints:
    - port: http
      path: {{ .Values.metrics.path | default "/actuator/prometheus" }}
      interval: {{ .Values.metrics.interval | default "30s" }}
      scrapeTimeout: {{ .Values.metrics.scrapeTimeout | default "10s" }}
{{- end }}
{{- end }}
```

### Library Chart — _external-secret.tpl

```yaml
# mg-deploy/_library/templates/_external-secret.tpl

{{- define "mg.externalSecret" -}}
{{- if .Values.externalSecret.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "mg.fullname" . }}
  labels: {{- include "mg.labels" . | nindent 4 }}
spec:
  refreshInterval: {{ .Values.externalSecret.refreshInterval | default "1h" }}
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-{{ include "mg.environment" . }}
  target:
    name: {{ include "mg.fullname" . }}-secrets
    creationPolicy: Owner
  data:
    {{- range .Values.externalSecret.keys }}
    - secretKey: {{ .secretKey }}
      remoteRef:
        key: {{ .remoteKey }}
    {{- end }}
{{- end }}
{{- end }}
```

### Пример values.yaml для сервиса (ПОЛНЫЙ)

```yaml
# mg-deploy/services/engine/values.yaml

# Базовые настройки
nameOverride: ""
fullnameOverride: ""
replicaCount: 1
environment: production  # development/staging/production

# Image
image:
  repository: shykhov/mg.engine
  tag: ""  # Управляется Image Updater
  pullPolicy: IfNotPresent

# Для приватного registry
imagePullSecrets:
  - name: dockerhub-credentials

# Service Account
serviceAccount:
  create: true
  name: ""
  annotations: {}

# Service
service:
  type: ClusterIP
  port: 8080
  annotations: {}
  extraPorts: []

# Spring Profile
springProfile: kubernetes

# Resources
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Probes
probes:
  liveness:
    enabled: true
    path: /actuator/health/liveness
    initialDelaySeconds: 30
    periodSeconds: 10
  readiness:
    enabled: true
    path: /actuator/health/readiness
    initialDelaySeconds: 5
    periodSeconds: 5
  startup:
    enabled: true
    path: /actuator/health/liveness
    initialDelaySeconds: 10
    failureThreshold: 30

# Autoscaling
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 3
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80

# PodDisruptionBudget
pdb:
  enabled: false
  # minAvailable: 1
  maxUnavailable: 1

# Metrics
metrics:
  enabled: true
  path: /actuator/prometheus
  interval: 30s

# Network Policy
networkPolicy:
  enabled: true
  allowExternalHTTPS: false  # Для сервисов без внешних API

# External Secrets
externalSecret:
  enabled: true
  refreshInterval: 1h
  keys:
    - secretKey: DB_PASSWORD
      remoteKey: ENGINE_DB_PASSWORD
    - secretKey: DB_USERNAME
      remoteKey: ENGINE_DB_USERNAME

# Environment variables
env:
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "kafka-kafka-bootstrap.kafka.svc:9092"
  - name: DB_HOST
    value: "postgres-engine-rw.databases.svc"
  - name: DB_NAME
    value: "engine"

# Tmp directory (для readOnlyRootFilesystem)
tmpDir:
  enabled: true
  sizeLimit: 100Mi

# Additional volumes
volumes: []
volumeMounts: []

# Scheduling
nodeSelector: {}
tolerations: []
affinity: {}
topologySpreadConstraints: []

# Sidecars
sidecars: []
```

### Пример: Сервис с sidecar (Broker + CCXT)

```yaml
# mg-deploy/services/broker/values.yaml
image:
  repository: shykhov/mg.broker
  tag: ""

environment: production
replicaCount: 1

service:
  port: 8080

networkPolicy:
  enabled: true
  allowExternalHTTPS: true  # Broker нужен доступ к биржам

externalSecret:
  enabled: true
  keys:
    - secretKey: BINANCE_API_KEY
      remoteKey: BROKER_BINANCE_API_KEY
    - secretKey: BINANCE_SECRET
      remoteKey: BROKER_BINANCE_SECRET
    - secretKey: BYBIT_API_KEY
      remoteKey: BROKER_BYBIT_API_KEY
    - secretKey: BYBIT_SECRET
      remoteKey: BROKER_BYBIT_SECRET

# Изолированный CCXT клиент как sidecar
sidecars:
  - name: ccxt-proxy
    image: shykhov/mg.ccxt:latest
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: false  # Node.js требует write
      capabilities:
        drop: ["ALL"]
    ports:
      - containerPort: 50051
        name: grpc
    env:
      - name: CCXT_EXCHANGES
        value: "binance,bybit,okx"
      - name: GRPC_PORT
        value: "50051"
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

env:
  - name: CCXT_GRPC_URL
    value: "localhost:50051"
  - name: KAFKA_BOOTSTRAP_SERVERS
    value: "kafka-kafka-bootstrap.kafka.svc:9092"

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi
```

---

## Структура mg-infrastructure

```
mg-infrastructure/
├── bootstrap/
│   └── root.yaml               # App-of-Apps (точка входа)
│
├── projects/
│   ├── platform.yaml           # AppProject для infrastructure
│   └── applications.yaml       # AppProject для сервисов
│
├── applicationsets/
│   ├── services.yaml           # Git generator → services/*
│   └── databases.yaml          # Git generator → databases/*
│
├── image-updaters/
│   └── services.yaml           # ImageUpdater annotations (stable)
│
├── base/
│   ├── argocd/
│   │   ├── values.yaml
│   │   └── repository-credentials.yaml
│   ├── argocd-image-updater/
│   ├── external-secrets/
│   │   ├── values.yaml
│   │   └── cluster-secret-stores.yaml
│   ├── tailscale/
│   │   ├── values.yaml
│   │   ├── connector.yaml
│   │   └── ingresses.yaml
│   ├── traefik/
│   │   ├── values.yaml
│   │   └── middlewares.yaml
│   ├── cert-manager/
│   ├── longhorn/
│   ├── metallb/
│   │   └── config.yaml
│   ├── kube-prometheus-stack/
│   │   ├── values.yaml
│   │   └── alertmanager-config.yaml
│   ├── loki/
│   │   └── values.yaml
│   ├── promtail/
│   │   └── values.yaml
│   ├── minio/
│   ├── velero/
│   ├── kafka/                  # Strimzi
│   │   ├── operator.yaml
│   │   └── kafka-cluster.yaml
│   └── cloudnative-pg/         # PostgreSQL Operator
│       └── values.yaml
│
├── databases/
│   ├── postgres-engine.yaml    # Cluster CRD
│   └── postgres-broker.yaml
│
├── security/
│   ├── pod-security-standards.yaml
│   ├── rbac/
│   └── registry-credentials.yaml
│
└── scripts/
    └── bootstrap.sh
```

### ApplicationSet для сервисов

```yaml
# mg-infrastructure/applicationsets/services.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: services
  namespace: argocd
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - git:
        repoURL: git@github.com:mshykhov/mg-deploy.git
        revision: HEAD
        directories:
          - path: services/*
          - path: services/_library
            exclude: true
  template:
    metadata:
      name: '{{ .path.basename }}'
      labels:
        app.kubernetes.io/part-of: mg-central
        environment: production
      annotations:
        # Image Updater annotations (stable approach)
        argocd-image-updater.argoproj.io/image-list: 'app=shykhov/mg.{{ .path.basename }}'
        argocd-image-updater.argoproj.io/app.update-strategy: semver
        argocd-image-updater.argoproj.io/app.allow-tags: 'regexp:^v[0-9]+\.[0-9]+\.[0-9]+$'
        argocd-image-updater.argoproj.io/write-back-method: git
        argocd-image-updater.argoproj.io/git-branch: main
    spec:
      project: applications
      source:
        repoURL: git@github.com:mshykhov/mg-deploy.git
        targetRevision: HEAD
        path: 'services/{{ .path.basename }}'
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{ .path.basename }}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - PrunePropagationPolicy=foreground
          - ServerSideApply=true
```

### ArgoCD Repository Credentials

```yaml
# mg-infrastructure/base/argocd/repository-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: mg-deploy-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:mshykhov/mg-deploy.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    # Генерируется: ssh-keygen -t ed25519 -C "argocd@mg-central"
    # Public key добавляется в GitHub Deploy Keys (read-only)
    -----END OPENSSH PRIVATE KEY-----
---
apiVersion: v1
kind: Secret
metadata:
  name: mg-infrastructure-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: git@github.com:mshykhov/mg-infrastructure.git
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    -----END OPENSSH PRIVATE KEY-----
```

### Docker Registry Credentials

```yaml
# mg-infrastructure/security/registry-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-credentials
  namespace: default  # Копируется в каждый namespace через ArgoCD
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "https://index.docker.io/v1/": {
          "auth": "base64(username:password)"
        }
      }
    }
```

**Лучше через ESO:**

```yaml
# mg-infrastructure/security/registry-external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dockerhub-credentials
  namespace: default
spec:
  refreshInterval: 24h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-production
  target:
    name: dockerhub-credentials
    creationPolicy: Owner
    template:
      type: kubernetes.io/dockerconfigjson
      data:
        .dockerconfigjson: |
          {
            "auths": {
              "https://index.docker.io/v1/": {
                "auth": "{{ .DOCKER_AUTH }}"
              }
            }
          }
  data:
    - secretKey: DOCKER_AUTH
      remoteRef:
        key: DOCKER_REGISTRY_AUTH
```

---

## PostgreSQL — CloudNativePG

### Установка Operator

```yaml
# mg-infrastructure/base/cloudnative-pg/operator.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudnative-pg
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://cloudnative-pg.github.io/charts
    chart: cloudnative-pg
    targetRevision: 0.22.0
    helm:
      values: |
        monitoring:
          podMonitorEnabled: true
  destination:
    server: https://kubernetes.default.svc
    namespace: cnpg-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### PostgreSQL Cluster для сервиса

```yaml
# mg-infrastructure/databases/postgres-engine.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: postgres-engine
  namespace: databases
spec:
  instances: 1  # Для dev/small scale. Production: 3

  imageName: ghcr.io/cloudnative-pg/postgresql:16.4

  postgresql:
    parameters:
      shared_buffers: "256MB"
      max_connections: "100"

  storage:
    storageClass: longhorn
    size: 10Gi

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  bootstrap:
    initdb:
      database: engine
      owner: engine
      secret:
        name: postgres-engine-credentials

  backup:
    barmanObjectStore:
      destinationPath: s3://db-backups/engine
      endpointURL: http://minio.minio.svc:9000
      s3Credentials:
        accessKeyId:
          name: minio-credentials
          key: ACCESS_KEY
        secretAccessKey:
          name: minio-credentials
          key: SECRET_KEY
    retentionPolicy: "30d"

  monitoring:
    enablePodMonitor: true
---
# Credentials через ESO
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-engine-credentials
  namespace: databases
spec:
  refreshInterval: 24h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-production
  target:
    name: postgres-engine-credentials
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: ENGINE_DB_USERNAME
    - secretKey: password
      remoteRef:
        key: ENGINE_DB_PASSWORD
```

---

## Kafka — Strimzi

### Установка Operator

```yaml
# mg-infrastructure/base/kafka/operator.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: strimzi-operator
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://strimzi.io/charts/
    chart: strimzi-kafka-operator
    targetRevision: 0.43.0
    helm:
      values: |
        watchAnyNamespace: true
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Kafka Cluster

```yaml
# mg-infrastructure/base/kafka/kafka-cluster.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka
  namespace: kafka
spec:
  kafka:
    version: 3.8.0
    replicas: 1  # Для dev. Production: 3

    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true

    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      auto.create.topics.enable: "false"

    storage:
      type: persistent-claim
      size: 20Gi
      class: longhorn

    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi

    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml

  zookeeper:
    replicas: 1  # Для dev. Production: 3
    storage:
      type: persistent-claim
      size: 5Gi
      class: longhorn
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi

  entityOperator:
    topicOperator: {}
    userOperator: {}
---
# Kafka Topics
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: opportunities
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 604800000  # 7 days
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: engine-events
  namespace: kafka
  labels:
    strimzi.io/cluster: kafka
spec:
  partitions: 3
  replicas: 1
```

---

## Observability

### Prometheus + Grafana (kube-prometheus-stack)

```yaml
# mg-infrastructure/base/kube-prometheus-stack/values.yaml
kube-prometheus-stack:
  fullnameOverride: prometheus

  grafana:
    adminPassword: ""  # Из Doppler через ESO
    persistence:
      enabled: true
      storageClassName: longhorn
      size: 10Gi

    # Grafana доступ через Tailscale, не через Ingress
    ingress:
      enabled: false

    sidecar:
      dashboards:
        enabled: true
        searchNamespace: ALL
      datasources:
        enabled: true

    additionalDataSources:
      - name: Loki
        type: loki
        url: http://loki.monitoring.svc:3100
        access: proxy

  prometheus:
    prometheusSpec:
      retention: 15d
      retentionSize: 45GB

      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: longhorn
            resources:
              requests:
                storage: 50Gi

      serviceMonitorSelectorNilUsesHelmValues: false
      podMonitorSelectorNilUsesHelmValues: false

      resources:
        requests:
          cpu: 200m
          memory: 512Mi
        limits:
          cpu: 1000m
          memory: 2Gi

  alertmanager:
    alertmanagerSpec:
      storage:
        volumeClaimTemplate:
          spec:
            storageClassName: longhorn
            resources:
              requests:
                storage: 5Gi
```

### Alertmanager Config

```yaml
# mg-infrastructure/base/kube-prometheus-stack/alertmanager-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-prometheus-alertmanager
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m

    route:
      receiver: telegram
      group_by: ['alertname', 'namespace', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - receiver: telegram
          matchers:
            - severity =~ "critical|warning"
        - receiver: 'null'
          matchers:
            - alertname = "Watchdog"

    receivers:
      - name: 'null'

      - name: telegram
        telegram_configs:
          - bot_token: '{{ .TELEGRAM_BOT_TOKEN }}'
            chat_id: {{ .TELEGRAM_CHAT_ID }}
            api_url: https://api.telegram.org
            parse_mode: HTML
            message: |
              {{ "{{" }} range .Alerts {{ "}}" }}
              <b>{{ "{{" }} .Status | toUpper {{ "}}" }}</b>: {{ "{{" }} .Labels.alertname {{ "}}" }}
              <b>Severity:</b> {{ "{{" }} .Labels.severity {{ "}}" }}
              <b>Namespace:</b> {{ "{{" }} .Labels.namespace {{ "}}" }}
              <b>Description:</b> {{ "{{" }} .Annotations.description {{ "}}" }}
              {{ "{{" }} end {{ "}}" }}

    inhibit_rules:
      - source_matchers:
          - severity = critical
        target_matchers:
          - severity = warning
        equal: ['alertname', 'namespace']
```

### Loki

```yaml
# mg-infrastructure/base/loki/values.yaml
loki:
  deploymentMode: SingleBinary

  loki:
    auth_enabled: false

    storage:
      type: s3
      s3:
        endpoint: http://minio.minio.svc:9000
        bucketnames: loki-chunks
        access_key_id: ${MINIO_ACCESS_KEY}
        secret_access_key: ${MINIO_SECRET_KEY}
        s3ForcePathStyle: true
        insecure: true

    schemaConfig:
      configs:
        - from: 2024-01-01
          store: tsdb
          object_store: s3
          schema: v13
          index:
            prefix: index_
            period: 24h

    limits_config:
      retention_period: 30d
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20

  singleBinary:
    replicas: 1
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    persistence:
      enabled: true
      storageClass: longhorn
      size: 10Gi

  gateway:
    enabled: false

  monitoring:
    serviceMonitor:
      enabled: true
```

### Promtail

```yaml
# mg-infrastructure/base/promtail/values.yaml
promtail:
  config:
    clients:
      - url: http://loki.monitoring.svc:3100/loki/api/v1/push
        tenant_id: fake  # Required even with auth disabled

    snippets:
      pipelineStages:
        - cri: {}
        - multiline:
            firstline: '^\d{4}-\d{2}-\d{2}'
            max_wait_time: 3s
        - labeldrop:
            - filename
            - stream

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            target_label: app
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
          - source_labels: [__meta_kubernetes_pod_container_name]
            target_label: container
        pipeline_stages:
          - cri: {}

  resources:
    requests:
      cpu: 50m
      memory: 64Mi
    limits:
      cpu: 200m
      memory: 128Mi

  tolerations:
    - effect: NoSchedule
      operator: Exists

  serviceMonitor:
    enabled: true
```

---

## Backup Strategy

### Velero + MinIO

```yaml
# mg-infrastructure/base/minio/values.yaml
minio:
  mode: standalone

  persistence:
    enabled: true
    storageClass: longhorn
    size: 100Gi

  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  buckets:
    - name: velero-backups
      policy: none
    - name: db-backups
      policy: none
    - name: loki-chunks
      policy: none

  # Credentials через ESO
  existingSecret: minio-credentials
```

```yaml
# mg-infrastructure/base/velero/values.yaml
velero:
  initContainers:
    - name: velero-plugin-for-aws
      image: velero/velero-plugin-for-aws:v1.10.0
      volumeMounts:
        - mountPath: /target
          name: plugins

  configuration:
    backupStorageLocation:
      - name: default
        provider: aws
        bucket: velero-backups
        config:
          region: minio
          s3ForcePathStyle: "true"
          s3Url: http://minio.minio.svc:9000

    volumeSnapshotLocation:
      - name: default
        provider: aws
        config:
          region: minio

  credentials:
    secretContents:
      cloud: |
        [default]
        aws_access_key_id=${MINIO_ACCESS_KEY}
        aws_secret_access_key=${MINIO_SECRET_KEY}

  schedules:
    daily-full:
      disabled: false
      schedule: "0 3 * * *"
      useOwnerReferencesInBackup: false
      template:
        ttl: 720h  # 30 days
        includedNamespaces:
          - "*"
        excludedNamespaces:
          - kube-system
          - velero
          - minio
          - monitoring
          - cnpg-system
        includedResources:
          - "*"
        storageLocation: default

    hourly-apps:
      disabled: false
      schedule: "0 * * * *"
      template:
        ttl: 168h  # 7 days
        includedNamespaces:
          - engine
          - broker
          - frontend
        includedResources:
          - deployments
          - services
          - configmaps
          - secrets
          - persistentvolumeclaims
        storageLocation: default

  metrics:
    serviceMonitor:
      enabled: true
```

### Disaster Recovery Plan

| Метрика | Значение | Комментарий |
|---------|----------|-------------|
| **RPO** (Recovery Point Objective) | 1 час | Максимальная потеря данных |
| **RTO** (Recovery Time Objective) | 4 часа | Время восстановления |

**Процедура восстановления:**

```bash
# 1. Список доступных бэкапов
velero backup get

# 2. Восстановление полного кластера
velero restore create --from-backup daily-full-20241127

# 3. Проверка статуса
velero restore describe <restore-name>

# 4. Проверка приложений
kubectl get pods -A
argocd app list

# 5. PostgreSQL восстановление (отдельно, через CNPG)
kubectl cnpg restore postgres-engine \
  --backup postgres-engine-backup-20241127
```

---

## Security

### Pod Security Standards

```yaml
# mg-infrastructure/security/pod-security-standards.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: engine
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: broker
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: databases
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
---
apiVersion: v1
kind: Namespace
metadata:
  name: kafka
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: restricted
```

### RBAC для разработчиков

```yaml
# mg-infrastructure/security/rbac/developer-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer
rules:
  # Read-only для большинства ресурсов
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps", "events"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]

  # Debugging
  - apiGroups: [""]
    resources: ["pods/exec", "pods/portforward"]
    verbs: ["create"]

  # Secrets — только list (без get содержимого)
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers
subjects:
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: developer
  apiGroup: rbac.authorization.k8s.io
```

---

## CI/CD Flow

```
┌──────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────┐
│  Commit  │────▶│  GitHub  │────▶│   Docker    │────▶│  Docker  │
│  to code │     │  Actions │     │   Build     │     │   Hub    │
└──────────┘     └──────────┘     └─────────────┘     └────┬─────┘
                                                           │
                                                           ▼
┌──────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────┐
│   Pod    │◀────│  ArgoCD  │◀────│  mg-deploy  │◀────│  Image   │
│  Update  │     │   Sync   │     │  (commit)   │     │  Updater │
└──────────┘     └──────────┘     └─────────────┘     └──────────┘
```

**Нет бесконечных CI loops** — Image Updater коммитит в mg-deploy, не в mg-central.

---

## Bootstrap нового кластера

```bash
#!/bin/bash
# scripts/bootstrap.sh

set -euo pipefail

echo "=== MG-Central Kubernetes Bootstrap ==="
echo ""

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для проверки успешности
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1 failed${NC}"
        exit 1
    fi
}

# 1. Проверка prerequisites
echo "Step 1: Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm required"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "No cluster connection"; exit 1; }
check_status "Prerequisites check"

# 2. MetalLB
echo ""
echo "Step 2: Installing MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml
kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s
check_status "MetalLB installed"

echo -e "${YELLOW}Configure MetalLB IP pool:${NC}"
read -p "Enter IP range (e.g., 192.168.1.240-192.168.1.250): " IP_RANGE
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - ${IP_RANGE}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
EOF
check_status "MetalLB configured"

# 3. Longhorn
echo ""
echo "Step 3: Installing Longhorn..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.7.2/deploy/longhorn.yaml
echo "Waiting for Longhorn (this may take a few minutes)..."
kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s
check_status "Longhorn installed"

# 4. ArgoCD
echo ""
echo "Step 4: Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.2/manifests/install.yaml
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
check_status "ArgoCD installed"

# 5. External Secrets Operator
echo ""
echo "Step 5: Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm upgrade --install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace \
  --set installCRDs=true \
  --wait
check_status "External Secrets Operator installed"

# 6. Doppler Token
echo ""
echo -e "${YELLOW}Step 6: Configure Doppler${NC}"
echo "1. Go to Doppler → Project → Access → Service Tokens"
echo "2. Generate token for production environment"
read -p "Doppler Service Token (dp.st.xxx): " DOPPLER_TOKEN

kubectl create secret generic doppler-token \
  -n external-secrets \
  --from-literal=dopplerToken="${DOPPLER_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -
check_status "Doppler token configured"

# 7. Tailscale Operator
echo ""
echo -e "${YELLOW}Step 7: Configure Tailscale${NC}"
echo "1. Go to Tailscale Admin Console → Settings → OAuth clients"
echo "2. Generate client with scopes: devices, routes, dns"
read -p "Client ID: " TS_CLIENT_ID
read -p "Client Secret: " TS_CLIENT_SECRET

helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  -n tailscale --create-namespace \
  --set oauth.clientId="${TS_CLIENT_ID}" \
  --set oauth.clientSecret="${TS_CLIENT_SECRET}" \
  --wait
check_status "Tailscale Operator installed"

# 8. SSH Key для Git repos
echo ""
echo -e "${YELLOW}Step 8: Configure Git SSH Access${NC}"
echo "Generating SSH key for ArgoCD..."

ssh-keygen -t ed25519 -C "argocd@mg-central" -f /tmp/argocd-key -N ""
echo ""
echo -e "${GREEN}Add this PUBLIC key to GitHub Deploy Keys:${NC}"
cat /tmp/argocd-key.pub
echo ""
read -p "Press Enter after adding the key to GitHub..."

kubectl create secret generic mg-repos-ssh \
  -n argocd \
  --from-file=sshPrivateKey=/tmp/argocd-key \
  --dry-run=client -o yaml | kubectl apply -f -
rm /tmp/argocd-key /tmp/argocd-key.pub
check_status "Git SSH key configured"

# 9. Apply root Application
echo ""
echo "Step 9: Applying root Application..."
kubectl apply -f bootstrap/root.yaml
check_status "Root Application applied"

# 10. Output access info
echo ""
echo "=========================================="
echo -e "${GREEN}=== BOOTSTRAP COMPLETE ===${NC}"
echo "=========================================="
echo ""
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "Access methods:"
echo "  1. Via Tailscale (recommended):"
echo "     - Install Tailscale on your device"
echo "     - Login with same account used for OAuth"
echo "     - Access: https://argocd.tailnet-xxxx.ts.net"
echo ""
echo "  2. Via port-forward (temporary):"
echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Next steps:"
echo "  1. Wait for ArgoCD to sync all infrastructure (~5-10 min)"
echo "  2. Check: argocd app list"
echo "  3. Access Grafana/ArgoCD/etc via Tailscale"
echo ""
echo -e "${YELLOW}Don't forget to:${NC}"
echo "  - Add secrets to Doppler (DB passwords, API keys)"
echo "  - Configure Tailscale ACLs"
echo "  - Set up Alertmanager receivers (Telegram token)"
```

---

## Инструменты — Итоговая таблица

### Core (обязательные)

| Инструмент | Назначение | Лицензия | Почему выбран |
|------------|-----------|----------|---------------|
| ArgoCD | GitOps CD | Apache 2.0 | Стандарт индустрии |
| ArgoCD Image Updater | Auto image updates | Apache 2.0 | Интеграция с ArgoCD |
| External Secrets Operator | Secret sync | Apache 2.0 | Vendor-neutral, CNCF |
| **Doppler** | Secret management | SaaS | UI, простота, unlimited envs |
| Traefik | Ingress Controller | MIT | Auto SSL, Gateway API |
| cert-manager | TLS certificates | Apache 2.0 | Стандарт для K8s |
| Longhorn | Distributed Storage | Apache 2.0 | Simple, K8s-native |
| MetalLB | Bare-metal LB | Apache 2.0 | Необходим для bare-metal |

### Data

| Инструмент | Назначение | Почему |
|------------|-----------|--------|
| CloudNativePG | PostgreSQL Operator | K8s-native, backups, HA |
| Strimzi | Kafka Operator | K8s-native, простой |

### Observability

| Инструмент | Назначение | Почему |
|------------|-----------|--------|
| kube-prometheus-stack | Metrics + Grafana | Всё в одном |
| Loki | Logs | Легче чем ELK |
| Promtail | Log collection | Интеграция с Loki |

### Backup

| Инструмент | Назначение |
|------------|-----------|
| Velero | K8s resource backup |
| MinIO | S3-compatible storage |

### Auth & Security

| Инструмент | Назначение | Почему |
|------------|-----------|--------|
| **Auth0** | Authentication | Free tier (7,500 MAU) |

### Network & Access

| Инструмент | Назначение | Почему |
|------------|-----------|--------|
| **Tailscale** | Zero-trust network | Free tier, простота |

---

## Стоимость решения

| Компонент | План | Цена |
|-----------|------|------|
| **Auth0** | Free (< 7,500 MAU) | $0 |
| **Doppler** | Developer (3 users) | $0 |
| **Tailscale** | Personal (3 users, 100 devices) | $0 |
| **Infrastructure** | Self-hosted | Только железо |
| **Итого** | | **$0/месяц** |

---

## Ссылки

### ArgoCD
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD Secret Management](https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/)
- [ArgoCD Image Updater](https://argocd-image-updater.readthedocs.io/)

### Secrets & Auth
- [External Secrets Operator](https://external-secrets.io/)
- [ESO + Doppler Provider](https://external-secrets.io/latest/provider/doppler/)
- [Doppler Pricing](https://www.doppler.com/pricing)
- [Auth0 Pricing](https://auth0.com/pricing)

### Data
- [CloudNativePG](https://cloudnative-pg.io/)
- [Strimzi](https://strimzi.io/)

### Network & Security
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- [Tailscale Connector](https://tailscale.com/kb/1441/kubernetes-operator-connector)

### Infrastructure
- [Helm Library Charts](https://helm.sh/docs/topics/library_charts/)
- [Velero + MinIO](https://velero.io/docs/main/contributions/minio/)
- [MetalLB Installation](https://metallb.io/installation/)
- [Longhorn Installation](https://longhorn.io/docs/latest/deploy/install/)

### Monitoring
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Grafana Loki](https://grafana.com/docs/loki/latest/)
