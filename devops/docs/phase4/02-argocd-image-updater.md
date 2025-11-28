# Phase 4: ArgoCD Image Updater + Multi-Environment

## Зачем

ArgoCD Image Updater автоматически отслеживает новые версии Docker образов и обновляет ArgoCD Applications. В комбинации с Matrix Generator обеспечивает автоматический деплой в dev (все версии) и prd (только stable).

## Архитектура

```
GitHub Actions              Docker Hub           ArgoCD Image Updater
     │                          │                        │
     ├─── push v0.1.0-rc.1 ─────►                        │
     │                          │                        │
     │                          │◄──── poll (2min) ──────┤
     │                          │                        │
     │                          │    ┌───────────────────┴───────────────────┐
     │                          │    │                                       │
     │                          │    ▼                                       ▼
     │                     DEV constraint: ~0-0              PRD constraint: ~0
     │                     (includes pre-release)            (stable only)
     │                          │                                       │
     │                          ▼                                       │
     │                     0.1.0-rc.1 ✓                                 │
     │                          │                                       │
     │                     Deploy to DEV                          (skip)
     │                          │
     ├─── push v0.1.0 ──────────►
     │                          │
     │                          │◄──── poll (2min) ──────┤
     │                          │                        │
     │                          ▼                        ▼
     │                     DEV: 0.1.0 ✓             PRD: 0.1.0 ✓
     │                          │                        │
     │                     Deploy to DEV          Deploy to PRD
```

## 1. Image Updater Application

`apps/templates/argocd-image-updater.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-image-updater
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "7"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argocd-image-updater
    targetRevision: "1.0.1"
    helm:
      values: |
        config:
          registries:
            - name: Docker Hub
              api_url: https://registry-1.docker.io
              prefix: docker.io
              ping: yes
              defaultns: library
              default: true
          log.level: info
        metrics:
          enabled: true
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 2. Matrix Generator ApplicationSet

Один ApplicationSet создаёт Applications для всех сервисов × всех окружений.

`apps/templates/services-appset.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: services
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "100"
spec:
  goTemplate: true
  goTemplateOptions: ["missingkey=error"]
  generators:
    - matrix:
        generators:
          # Environments
          - list:
              elements:
                - env: dev
                  # ~0-0: includes pre-release versions (0.1.0-rc.1, 0.1.0-beta.2)
                  imageConstraint: "~0-0"
                - env: prd
                  # ~0: stable versions only (0.1.0, 0.2.0)
                  imageConstraint: "~0"
          # Services from deployment repository
          - git:
              repoURL: {{ .Values.deploy.repoURL }}
              revision: {{ .Values.deploy.targetRevision }}
              directories:
                - path: services/*
                - path: services/_*
                  exclude: true
  template:
    metadata:
      name: '{{`{{ .path.basename }}`}}-{{`{{ .env }}`}}'
      labels:
        app: '{{`{{ .path.basename }}`}}'
        env: '{{`{{ .env }}`}}'
      annotations:
        # ArgoCD Image Updater
        argocd-image-updater.argoproj.io/image-list: 'app={{ .Values.dockerhub.username }}/{{`{{ .path.basename }}`}}:{{`{{ .imageConstraint }}`}}'
        argocd-image-updater.argoproj.io/app.update-strategy: semver
        argocd-image-updater.argoproj.io/app.helm.image-tag: image.tag
        argocd-image-updater.argoproj.io/write-back-method: argocd
    spec:
      project: default
      source:
        repoURL: {{ .Values.deploy.repoURL }}
        targetRevision: {{ .Values.deploy.targetRevision }}
        path: '{{`{{ .path.path }}`}}'
        helm:
          valueFiles:
            - values.yaml
            - 'values-{{`{{ .env }}`}}.yaml'
          valuesObject:
            imagePullSecrets:
              - name: dockerhub-credentials
      destination:
        server: {{ .Values.spec.destination.server }}
        namespace: '{{`{{ .path.basename }}`}}-{{`{{ .env }}`}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        managedNamespaceMetadata:
          labels:
            app: '{{`{{ .path.basename }}`}}'
            env: '{{`{{ .env }}`}}'
            dockerhub-pull: "true"
        syncOptions:
          - CreateNamespace=true
```

## 3. Helm Values Structure

### values.yaml (base)

```yaml
replicaCount: 1

image:
  repository: username/example-api
  pullPolicy: IfNotPresent
  tag: ""

# ... common settings
```

### values-dev.yaml (dev overrides)

```yaml
# Only dev-specific settings. Merged with values.yaml
# Base values are sufficient for dev - no overrides needed.
```

### values-prd.yaml (prd overrides)

```yaml
replicaCount: 2

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70
```

## 4. Semver Constraints

| Constraint | Описание | Примеры |
|------------|----------|---------|
| `~0-0` | Все 0.x.x + pre-release | 0.1.0-rc.1, 0.1.0, 0.2.0-beta.1 |
| `~0` | Только stable 0.x.x | 0.1.0, 0.2.0 (не 0.1.0-rc.1) |
| `1.x` | Любая 1.x.x | 1.0.0, 1.5.2 |
| `~1.2` | Только 1.2.x patches | 1.2.0, 1.2.5 |

## 5. Результат

Matrix Generator создаёт:

| Application | Namespace | Image Constraint | Auto-deploy |
|-------------|-----------|------------------|-------------|
| `example-api-dev` | `example-api-dev` | `~0-0` | pre-release + stable |
| `example-api-prd` | `example-api-prd` | `~0` | stable only |

## 6. CI/CD Flow (полный)

```
1. Developer: git tag v0.1.0-rc.1 && git push --tags
                    │
2. GitHub Actions:  ├─► Build multi-platform Docker image
                    ├─► Push to Docker Hub (0.1.0-rc.1)
                    │
3. Image Updater:   ├─► DEV: constraint ~0-0 matches → update
                    ├─► PRD: constraint ~0 doesn't match → skip
                    │
4. ArgoCD:          └─► Sync example-api-dev

--- After testing in DEV ---

5. Developer: git tag v0.1.0 && git push --tags
                    │
6. GitHub Actions:  ├─► Build multi-platform Docker image
                    ├─► Push to Docker Hub (0.1.0)
                    │
7. Image Updater:   ├─► DEV: constraint ~0-0 matches → update
                    ├─► PRD: constraint ~0 matches → update
                    │
8. ArgoCD:          └─► Sync both example-api-dev and example-api-prd
```

## 7. Проверка

```bash
# Pods Image Updater
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# Логи
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f

# Applications
kubectl get app -n argocd

# Проверить аннотации
kubectl get app example-api-dev -n argocd -o jsonpath='{.metadata.annotations}' | jq
```

## Troubleshooting

### Image Updater не видит приложение

Проверь аннотацию `argocd-image-updater.argoproj.io/image-list`.

### Не находит новые теги

```bash
kubectl exec -n argocd deploy/argocd-image-updater -- \
  argocd-image-updater test docker.io/username/example-api
```

### 401 Unauthorized при pull

Проверь:
1. Namespace label `dockerhub-pull: "true"`
2. ClusterExternalSecret создал secret в namespace
3. Doppler содержит `DOCKERHUB_USERNAME` и `DOCKERHUB_PULL_TOKEN`

```bash
kubectl get ns example-api-dev --show-labels
kubectl get externalsecret -n example-api-dev
kubectl get secret dockerhub-credentials -n example-api-dev
```

## Следующий шаг

Phase 5: Networking (Traefik, Tailscale Operator)
