# Phase 4: ArgoCD Image Updater

## Зачем

ArgoCD Image Updater автоматически отслеживает новые версии Docker образов и обновляет ArgoCD Applications. Обеспечивает автоматический деплой в dev (все версии включая pre-release) и prd (только stable).

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

## v1.0+ Breaking Change

**Image Updater v1.0+ использует CRD (`ImageUpdater`) вместо аннотаций на Applications.**

Docs: https://argocd-image-updater.readthedocs.io/en/stable/configuration/migration/

## Структура файлов

```
example-infrastructure/
├── apps/templates/
│   ├── argocd-image-updater.yaml    # Helm chart (wave 7)
│   ├── image-updater-config.yaml    # Application для CRs (wave 8)
│   └── services-appset.yaml         # ApplicationSet (без аннотаций!)
└── manifests/
    ├── infra/
    │   └── docker-credentials/
    │       └── dockerhub.yaml       # ClusterExternalSecret
    └── apps/
        └── image-updater/
            └── example-api.yaml     # ImageUpdater CR
```

## 1. Image Updater Helm Chart

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
              credentials: pullsecret:argocd/dockerhub-credentials
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

## 2. ImageUpdater CR

`manifests/apps/image-updater/example-api.yaml`:

```yaml
apiVersion: argocd-image-updater.argoproj.io/v1alpha1
kind: ImageUpdater
metadata:
  name: example-api
spec:
  namespace: argocd
  applicationRefs:
    # DEV: includes pre-release versions (0.1.0-rc.1, 0.1.0-beta.2)
    - namePattern: "example-api-dev"
      images:
        - alias: "app"
          imageName: "shykhovmyron/example-api:~0-0"
          commonUpdateSettings:
            updateStrategy: "semver"
          manifestTargets:
            helm:
              name: "image.repository"
              tag: "image.tag"
    # PRD: stable versions only (0.1.0, 0.2.0)
    - namePattern: "example-api-prd"
      images:
        - alias: "app"
          imageName: "shykhovmyron/example-api:~0"
          commonUpdateSettings:
            updateStrategy: "semver"
          manifestTargets:
            helm:
              name: "image.repository"
              tag: "image.tag"
```

## 3. Application для деплоя CRs

`apps/templates/image-updater-config.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: image-updater-config
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "8"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ .Values.spec.source.repoURL }}
    targetRevision: {{ .Values.spec.source.targetRevision }}
    path: manifests/apps/image-updater
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 4. Docker Hub Credentials

`manifests/infra/docker-credentials/dockerhub.yaml`:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterExternalSecret
metadata:
  name: dockerhub-credentials
spec:
  externalSecretName: dockerhub-credentials
  namespaceSelectors:
    - matchLabels:
        dockerhub-pull: "true"
  refreshTime: "1m"
  externalSecretSpec:
    secretStoreRef:
      name: doppler-shared
      kind: ClusterSecretStore
    refreshInterval: "1m"
    target:
      name: dockerhub-credentials
      creationPolicy: Owner
      template:
        type: kubernetes.io/dockerconfigjson
        data:
          .dockerconfigjson: |
            {"auths":{"https://index.docker.io/v1/":{"username":"{{ .username }}","password":"{{ .password }}","auth":"{{ printf "%s:%s" .username .password | b64enc }}"},"https://registry-1.docker.io":{"username":"{{ .username }}","password":"{{ .password }}","auth":"{{ printf "%s:%s" .username .password | b64enc }}"}}}
    data:
      - secretKey: username
        remoteRef:
          key: DOCKERHUB_USERNAME
      - secretKey: password
        remoteRef:
          key: DOCKERHUB_PULL_TOKEN
```

**Важно:** Два URL в auths:
- `https://index.docker.io/v1/` - для Kubernetes imagePullSecrets
- `https://registry-1.docker.io` - для Image Updater API

## 5. Semver Constraints

| Constraint | Описание | Примеры |
|------------|----------|---------|
| `~0-0` | Все 0.x.x + pre-release | 0.1.0-rc.1, 0.1.0, 0.2.0-beta.1 |
| `~0` | Только stable 0.x.x | 0.1.0, 0.2.0 (не 0.1.0-rc.1) |
| `1.x` | Любая 1.x.x | 1.0.0, 1.5.2 |
| `~1.2` | Только 1.2.x patches | 1.2.0, 1.2.5 |

## 6. CI/CD Flow

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

## Troubleshooting

### Проверка статуса

```bash
# Image Updater pods
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater

# Логи
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f

# ImageUpdater CRs
kubectl get imageupdater -n argocd

# Applications
kubectl get app -n argocd
```

### "No ImageUpdater CRs to process"

v1.0+ требует ImageUpdater CR. Аннотации на Applications больше не работают.

```bash
# Проверить что CR существует
kubectl get imageupdater -n argocd
```

### 401 Unauthorized / incorrect username or password

1. Проверь секрет в argocd namespace:
```bash
kubectl get secret dockerhub-credentials -n argocd
kubectl get secret dockerhub-credentials -n argocd -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq .
```

2. Проверь что оба URL есть в auths:
   - `https://index.docker.io/v1/`
   - `https://registry-1.docker.io`

3. Проверь credentials локально:
```bash
docker login -u USERNAME -p TOKEN
```

4. Проверь ConfigMap:
```bash
kubectl get configmap argocd-image-updater-config -n argocd -o yaml
```

5. Рестартни Image Updater после изменения секрета:
```bash
kubectl rollout restart deployment argocd-image-updater -n argocd
```

### "no valid auth entry for registry"

Секрет не содержит нужный registry URL. Добавь `https://registry-1.docker.io` в dockerconfigjson.

### Image Updater не подхватывает новый секрет

```bash
kubectl rollout restart deployment argocd-image-updater -n argocd
```

### Проверить registry connectivity

```bash
kubectl exec -n argocd deploy/argocd-image-updater -- \
  argocd-image-updater test docker.io/username/example-api
```

## Следующий шаг

Phase 5: Networking (Traefik, Tailscale Operator)
