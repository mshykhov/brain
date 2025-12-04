# OT Redis Operator

## Overview

OT-Container-Kit Redis Operator для Kubernetes-native Redis management.

## Installation

ArgoCD Application: `apps/templates/core/redis-operator.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: redis-operator
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  source:
    repoURL: https://ot-container-kit.github.io/helm-charts
    chart: redis-operator
    targetRevision: "0.18.1"
```

## Redis Modes

| Mode | Environment | CRDs Created |
|------|-------------|--------------|
| standalone | DEV | Redis |
| sentinel | PRD | RedisReplication + RedisSentinel |

## redis-instance Chart

Local Helm chart: `charts/redis-instance/`

### Templates

| File | Description |
|------|-------------|
| redis-standalone.yaml | Redis CRD для standalone mode |
| redis-replication.yaml | RedisReplication CRD для sentinel mode |
| redis-sentinel.yaml | RedisSentinel CRD |
| external-secret.yaml | ExternalSecret для Doppler password |
| servicemonitor.yaml | Prometheus ServiceMonitor |

### Values Structure

```yaml
# charts/redis-instance/values.yaml
mode: standalone  # or sentinel for PRD

image:
  repository: quay.io/opstree/redis
  tag: v7.0.15

auth:
  enabled: true
  secretKey: password
  secretStore: ""  # doppler-dev or doppler-prd
  key: ""          # Doppler key name
```

## ApplicationSet

Matrix generator: environments × service configs

```yaml
# apps/templates/data/redis-clusters.yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - env: dev
              - env: prd
        - git:
            files:
              - path: databases/*/redis/*.yaml
```

## Value Precedence

1. `helm-values/data/redis-<env>-defaults.yaml` (base)
2. `databases/<service>/redis/<instance>.yaml` (service config)
3. `databases/<service>/redis/<instance>-<env>.yaml` (optional env override)

## Environment Defaults

### DEV (`redis-dev-defaults.yaml`)

```yaml
mode: standalone
resources:
  requests: { cpu: 50m, memory: 64Mi }
  limits: { cpu: 200m, memory: 128Mi }
auth:
  enabled: true
  secretStore: doppler-dev
```

### PRD (`redis-prd-defaults.yaml`)

```yaml
mode: sentinel
clusterSize: 2  # 1 master + 1 replica
resources:
  requests: { cpu: 200m, memory: 256Mi }
  limits: { cpu: "1", memory: 512Mi }
pdb:
  enabled: true
  minAvailable: 1
auth:
  enabled: true
  secretStore: doppler-prd
```

## Generated Services (PRD Sentinel)

| Service | Port | Description |
|---------|------|-------------|
| `<name>` | 6379 | Round-robin to all Redis pods |
| `<name>-master` | 6379 | Always points to master |
| `<name>-replica` | 6379 | Only replicas |
| `<name>-sentinel` | 26379 | Sentinel discovery |

**IMPORTANT**: Для write operations использовать `<name>-master` service!

## Connection Example

```yaml
# deploy: services/example-api/values-prd.yaml
extraEnv:
  - name: SPRING_DATA_REDIS_HOST
    value: "example-api-cache-prd-master"  # Use -master for PRD!
  - name: SPRING_DATA_REDIS_PORT
    value: "6379"
  - name: SPRING_DATA_REDIS_PASSWORD
    valueFrom:
      secretKeyRef:
        name: example-api-cache-prd
        key: password
```

## Official Docs

- [OT Redis Operator](https://redis-operator.opstree.dev/)
- [Redis CRD Reference](https://redis-operator.opstree.dev/docs/crd-reference/)
