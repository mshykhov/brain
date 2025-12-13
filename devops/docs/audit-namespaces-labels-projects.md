# Аудит: Namespaces, Labels, ArgoCD Projects

Дата: 2025-12-05

## Официальные Best Practices

### Kubernetes Namespaces
- Используй namespaces для изоляции по командам/проектам
- Используй **labels** для различия версий/environments внутри namespace
- Namespace names должны быть RFC 1123 DNS labels

### Kubernetes Labels (Recommended)
| Label | Описание | Пример |
|-------|----------|--------|
| `app.kubernetes.io/name` | Имя приложения | `mysql` |
| `app.kubernetes.io/instance` | Уникальный instance | `mysql-dev` |
| `app.kubernetes.io/version` | Версия | `5.7.21` |
| `app.kubernetes.io/component` | Компонент | `database` |
| `app.kubernetes.io/part-of` | Часть большего app | `wordpress` |
| `app.kubernetes.io/managed-by` | Инструмент управления | `Helm` |

### ArgoCD Projects
- **НЕ** использовать `default` project в production
- Создавать отдельные projects для разных команд/доменов
- Ограничивать `sourceRepos`, `destinations`, `clusterResourceWhitelist`

---

## Текущее Состояние

### ✅ Что сделано правильно

1. **App namespaces имеют хорошие labels:**
   ```yaml
   example-api-dev:
     app: example-api
     env: dev
     dockerhub-pull: "true"
   ```

2. **Helm deployments имеют стандартные labels:**
   ```yaml
   app.kubernetes.io/name: example-api
   app.kubernetes.io/instance: example-api-dev
   app.kubernetes.io/managed-by: Helm
   ```

3. **Логичная структура namespaces:**
   - Per-app/per-env: `example-api-dev`, `example-api-prd`
   - Functional: `monitoring`, `tailscale`, `cloudflare`

4. **Network Policies** в ArgoCD namespace

5. **managedNamespaceMetadata** в ApplicationSet автоматически добавляет labels

---

### ❌ Проблемы

#### 1. ArgoCD Projects — ВСЁ в `default`

```bash
$ kubectl get applications -n argocd -o custom-columns='NAME:.metadata.name,PROJECT:.spec.project'
NAME                          PROJECT
alloy                         default
cloudflare-tunnel             default
example-api-dev               default
kube-prometheus-stack         default
...все 31 приложение в default
```

**Проблема:** `default` project имеет полные права (`*` на всё). Нет изоляции между infrastructure и applications.

#### 2. Infrastructure Namespaces — нет labels

```bash
monitoring           kubernetes.io/metadata.name=monitoring
tailscale            kubernetes.io/metadata.name=tailscale
longhorn-system      kubernetes.io/metadata.name=longhorn-system
external-secrets     kubernetes.io/metadata.name=external-secrets
```

Только автоматический `kubernetes.io/metadata.name`, нет:
- `tier` (infrastructure/application)
- `team` (platform/backend)
- `app.kubernetes.io/*` стандартных labels

#### 3. Некоторые Deployments без labels

```bash
cloudflare         cloudflared                 <none>
tailscale          operator                    <none>
```

#### 4. Нет Resource Management

```bash
$ kubectl get resourcequota -A
No resources found

$ kubectl get limitrange -A
No resources found
```

#### 5. Network Policies только в ArgoCD

```bash
$ kubectl get networkpolicy -A
NAMESPACE   NAME
argocd      argocd-application-controller-network-policy
argocd      argocd-server-network-policy
...только argocd
```

---

## Рекомендации

### 1. Создать ArgoCD Projects

```yaml
# charts/argocd-config/templates/projects.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: infrastructure
  namespace: argocd
spec:
  description: Core infrastructure components
  sourceRepos:
    - 'git@github.com:your-org/infrastructure.git'
  destinations:
    - namespace: 'longhorn-system'
      server: https://kubernetes.default.svc
    - namespace: 'external-secrets'
      server: https://kubernetes.default.svc
    - namespace: 'metallb-system'
      server: https://kubernetes.default.svc
    - namespace: 'cert-manager'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: network
  namespace: argocd
spec:
  description: Network and ingress components
  sourceRepos:
    - 'git@github.com:your-org/infrastructure.git'
  destinations:
    - namespace: 'ingress-nginx'
      server: https://kubernetes.default.svc
    - namespace: 'tailscale'
      server: https://kubernetes.default.svc
    - namespace: 'cloudflare'
      server: https://kubernetes.default.svc
    - namespace: 'oauth2-proxy'
      server: https://kubernetes.default.svc
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: monitoring
  namespace: argocd
spec:
  description: Monitoring and observability
  sourceRepos:
    - 'git@github.com:your-org/infrastructure.git'
  destinations:
    - namespace: 'monitoring'
      server: https://kubernetes.default.svc
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: applications
  namespace: argocd
spec:
  description: Business applications
  sourceRepos:
    - 'git@github.com:your-org/deploy.git'
  destinations:
    - namespace: 'example-*'
      server: https://kubernetes.default.svc
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange
```

### 2. Стандартизировать Namespace Labels

```yaml
# Добавить в каждый namespace:
metadata:
  labels:
    # Стандартные K8s labels
    app.kubernetes.io/part-of: example-platform
    app.kubernetes.io/managed-by: argocd

    # Организационные labels
    tier: infrastructure  # infrastructure | network | monitoring | application
    team: platform        # platform | backend | frontend

    # Функциональные (уже есть)
    dockerhub-pull: "true"
    auth0-oidc: "true"
```

**Tier mapping:**
| Tier | Namespaces |
|------|------------|
| infrastructure | longhorn-system, external-secrets, cert-manager, cnpg-system, redis-operator |
| network | ingress-nginx, tailscale, cloudflare, oauth2-proxy, external-dns |
| monitoring | monitoring |
| application | example-api-*, example-ui-* |
| cicd | argocd |
| backup | velero |

### 3. Добавить Labels в Helm Charts

Для `cloudflared`:
```yaml
# charts/cloudflare-tunnel/templates/deployment.yaml
metadata:
  labels:
    app.kubernetes.io/name: cloudflared
    app.kubernetes.io/instance: cloudflared
    app.kubernetes.io/component: tunnel
    app.kubernetes.io/part-of: cloudflare
    app.kubernetes.io/managed-by: Helm
```

### 4. Resource Quotas для Production

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: example-api-prd
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
```

### 5. LimitRange для Defaults

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: example-api-prd
spec:
  limits:
    - default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      type: Container
```

---

## Приоритет Исправлений

| # | Задача | Сложность | Влияние |
|---|--------|-----------|---------|
| 1 | Создать ArgoCD Projects | Medium | High |
| 2 | Стандартизировать namespace labels | Low | Medium |
| 3 | Добавить labels в cloudflared/tailscale | Low | Low |
| 4 | ResourceQuota для prd namespaces | Medium | Medium |
| 5 | Network Policies для критичных ns | High | High |

---

## Ссылки

- [K8s Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [K8s Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [ArgoCD Projects](https://argo-cd.readthedocs.io/en/stable/user-guide/projects/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
