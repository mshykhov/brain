# Cloudflared Kubernetes Deployment

## Overview

Cloudflared connector запускается в K8s и устанавливает outbound connection к Cloudflare Edge.

**Sync Waves:**
- Wave 20: ExternalSecret (CF_TUNNEL_TOKEN)
- Wave 21: cloudflared Deployment

## Структура файлов

```
example-infrastructure/
├── apps/templates/network/
│   └── cloudflare-tunnel.yaml      # ArgoCD Application (wave 21)
├── charts/credentials/templates/
│   └── cloudflare.yaml             # ExternalSecret (wave 20)
└── charts/cloudflare-tunnel/       # Helm chart
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
        ├── namespace.yaml
        └── deployment.yaml
```

## 1. ExternalSecret

`charts/credentials/templates/cloudflare.yaml`:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflare-tunnel-token
  namespace: cloudflare
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: tunnel-credentials
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: CF_TUNNEL_TOKEN
```

## 2. Helm Chart

### Chart.yaml
```yaml
apiVersion: v2
name: cloudflare-tunnel
description: Cloudflared tunnel connector
type: application
version: 1.0.0
appVersion: "2024.11.0"
```

### values.yaml
```yaml
replicas: 2

image:
  repository: cloudflare/cloudflared
  tag: "2024.11.0"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 10m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi
```

### templates/namespace.yaml
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cloudflare
```

### templates/deployment.yaml
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare
spec:
  replicas: {{ .Values.replicas }}
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          args:
            - tunnel
            - --no-autoupdate
            - --metrics
            - 0.0.0.0:2000
            - run
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: tunnel-credentials
                  key: token
          ports:
            - name: metrics
              containerPort: 2000
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet:
              path: /ready
              port: 2000
            initialDelaySeconds: 10
            periodSeconds: 10
          securityContext:
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]
      securityContext:
        seccompProfile:
          type: RuntimeDefault
```

## 3. ArgoCD Application

`apps/templates/network/cloudflare-tunnel.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudflare-tunnel
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "21"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ .Values.spec.source.repoURL }}
    targetRevision: {{ .Values.spec.source.targetRevision }}
    path: charts/cloudflare-tunnel
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: cloudflare
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## 4. Настройка Public Hostnames

После деплоя, в Cloudflare Zero Trust Dashboard:

1. Tunnels → k8s-prd-tunnel → Configure
2. Public Hostname → Add
3. Настроить routes:

| Subdomain | Domain | Path | Service |
|-----------|--------|------|---------|
| api | yourdomain.com | * | http://example-api.prd.svc.cluster.local:8080 |
| app | yourdomain.com | * | http://example-ui.prd.svc.cluster.local:80 |

## Проверка

```bash
# Pods запущены
kubectl get pods -n cloudflare

# Tunnel connected (в Zero Trust Dashboard)
# Status: HEALTHY, 2 connectors

# Public endpoint работает
curl https://api.yourdomain.com/actuator/health
```

## Troubleshooting

```bash
# Логи cloudflared
kubectl logs -n cloudflare -l app=cloudflared -f

# Metrics
kubectl port-forward -n cloudflare deployment/cloudflared 2000:2000
curl localhost:2000/metrics
```
