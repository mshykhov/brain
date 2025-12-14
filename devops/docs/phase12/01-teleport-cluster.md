# Teleport Cluster Installation

## 1. Overview

Teleport доступен через Tailscale Ingress с автоматическим TLS сертификатом.
- URL: `https://teleport.trout-paradise.ts.net`
- Internal-only доступ (более безопасно чем public)

## 2. Helm Values

`infrastructure/helm-values/core/teleport-cluster.yaml`:

```yaml
# Multiplex mode - single port for all protocols (SSH, gRPC, HTTPS)
proxyListenerMode: multiplex

# Disable ACME - TLS handled by Tailscale Ingress
acme: false

# Persistence
persistence:
  enabled: true
  storageClassName: longhorn
  size: 5Gi

# Resources
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Service - ClusterIP (exposed via Tailscale Ingress)
service:
  type: ClusterIP

log:
  level: INFO
```

## 3. ArgoCD Application

`infrastructure/apps/templates/core/teleport.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: teleport-cluster
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "20"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: infrastructure
  sources:
    - repoURL: https://charts.releases.teleport.dev
      chart: teleport-cluster
      targetRevision: "18.5.1"
      helm:
        valueFiles:
          - $values/helm-values/core/teleport-cluster.yaml
        valuesObject:
          clusterName: teleport.{{ .Values.global.tailnet }}.ts.net
          publicAddr:
            - teleport.{{ .Values.global.tailnet }}.ts.net:443
    - repoURL: {{ .Values.spec.source.repoURL }}
      targetRevision: {{ .Values.spec.source.targetRevision }}
      ref: values
  destination:
    server: {{ .Values.spec.destination.server }}
    namespace: teleport
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    managedNamespaceMetadata:
      labels:
        tier: infrastructure
        team: platform
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## 4. Tailscale Ingress (Direct)

В `infrastructure/charts/protected-services/values.yaml`:

```yaml
teleport:
  enabled: true
  direct: true          # Direct Tailscale Ingress, bypasses nginx
  namespace: teleport
  backend:
    name: teleport-cluster
    port: 443
```

Template `infrastructure/charts/protected-services/templates/tailscale-direct.yaml`:

```yaml
{{- range $name, $service := .Values.services }}
{{- if and $service.enabled $service.direct }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ $name }}-tailscale
  namespace: {{ $service.namespace }}
  annotations:
    tailscale.com/proxy-group: ingress-proxies
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - {{ $name }}
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ $service.backend.name }}
                port:
                  number: {{ $service.backend.port }}
{{- end }}
{{- end }}
```

## 5. Verify Installation

```bash
# Check pods
kubectl get pods -n teleport

# Check ingress
kubectl get ingress -n teleport

# Check Tailscale
kubectl get ingress teleport-tailscale -n teleport -o yaml

# Access
https://teleport.trout-paradise.ts.net
```

## 6. Create Initial Admin User (Optional)

До настройки SSO можно создать локального админа:

```bash
AUTH_POD=$(kubectl get pod -n teleport -l app=teleport-cluster -o jsonpath='{.items[0].metadata.name}')

# Create admin user
kubectl exec -n teleport -it $AUTH_POD -- tctl users add admin --roles=editor,access,auditor

# Follow the link to set password
```

## Next Steps

→ [02-auth0-oidc.md](02-auth0-oidc.md)
