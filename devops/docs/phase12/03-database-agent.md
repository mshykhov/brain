# Database Agent for CloudNativePG

## 1. Generate Join Token

```bash
AUTH_POD=$(kubectl get pod -n teleport -l app=teleport-cluster -o jsonpath='{.items[0].metadata.name}')

# Create token for database service
kubectl exec -n teleport $AUTH_POD -- tctl tokens add --type=db --ttl=1h
```

Сохрани токен.

## 2. Create Teleport CA Certificate

Для mTLS между Teleport и PostgreSQL:

```bash
# Export Teleport DB CA
kubectl exec -n teleport $AUTH_POD -- tctl auth sign \
  --format=db \
  --host=*.blackpoint-api-dev.svc.cluster.local,*.blackpoint-api-prd.svc.cluster.local,*.notifier-dev.svc.cluster.local,*.notifier-prd.svc.cluster.local \
  --out=server \
  --ttl=8760h

# This creates: server.crt, server.key, server.cas
```

## 3. Configure CloudNativePG for Teleport

Обновить CNPG cluster для использования Teleport CA.

`infrastructure/charts/cnpg-cluster/templates/cluster.yaml`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: {{ .Release.Name }}-cluster
spec:
  # ... existing config ...

  postgresql:
    parameters:
      # Enable SSL
      ssl: "on"
    pg_hba:
      # Allow Teleport agent with cert auth
      - hostssl all all 0.0.0.0/0 cert
      - hostssl all all ::/0 cert

  # Custom CA for Teleport
  certificates:
    serverCASecret: teleport-db-ca
    serverTLSSecret: teleport-db-tls
```

## 4. Create Database Agent Values

`infrastructure/charts/teleport-db-agent/values.yaml`:

```yaml
roles: db
proxyAddr: teleport.trout-paradise.ts.net:443
authToken: <join_token>

databases:
  # Dev databases
  - name: blackpoint-api-dev
    uri: blackpoint-api-main-db-dev-cluster-rw.blackpoint-api-dev.svc.cluster.local:5432
    protocol: postgres
    static_labels:
      env: dev
      app: blackpoint-api

  - name: notifier-dev
    uri: notifier-main-db-dev-cluster-rw.notifier-dev.svc.cluster.local:5432
    protocol: postgres
    static_labels:
      env: dev
      app: notifier

  # Prd databases
  - name: blackpoint-api-prd
    uri: blackpoint-api-main-db-prd-cluster-rw.blackpoint-api-prd.svc.cluster.local:5432
    protocol: postgres
    static_labels:
      env: prd
      app: blackpoint-api

  - name: notifier-prd
    uri: notifier-main-db-prd-cluster-rw.notifier-prd.svc.cluster.local:5432
    protocol: postgres
    static_labels:
      env: prd
      app: notifier

# Resources
resources:
  requests:
    cpu: 50m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi
```

## 5. Install via Helm

```bash
helm install teleport-db-agent teleport/teleport-kube-agent \
  --namespace teleport \
  --version 18.5.1 \
  -f values.yaml
```

Или через ArgoCD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: teleport-db-agent
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://charts.releases.teleport.dev
    chart: teleport-kube-agent
    targetRevision: 18.5.1
    helm:
      valuesObject:
        roles: db
        proxyAddr: teleport.trout-paradise.ts.net:443
        authToken: <token>
        databases:
          - name: blackpoint-api-dev
            uri: blackpoint-api-main-db-dev-cluster-rw.blackpoint-api-dev.svc.cluster.local:5432
            protocol: postgres
            static_labels:
              env: dev
              app: blackpoint-api
  destination:
    server: https://kubernetes.default.svc
    namespace: teleport
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 6. Create PostgreSQL Users

В каждом CNPG кластере создать пользователей для Teleport:

```bash
# Connect to PostgreSQL
kubectl exec -it -n blackpoint-api-dev blackpoint-api-main-db-dev-cluster-1 -- psql -U postgres

-- Create readonly user
CREATE ROLE teleport_readonly WITH LOGIN;
GRANT CONNECT ON DATABASE blackpoint TO teleport_readonly;
GRANT USAGE ON SCHEMA public TO teleport_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO teleport_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO teleport_readonly;

-- Create readwrite user
CREATE ROLE teleport_readwrite WITH LOGIN;
GRANT CONNECT ON DATABASE blackpoint TO teleport_readwrite;
GRANT USAGE ON SCHEMA public TO teleport_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO teleport_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO teleport_readwrite;
```

## 7. Verify Database Registration

```bash
# List registered databases
tsh db ls

# Should show:
# Name                 Description  Labels
# -------------------- ------------ ------
# blackpoint-api-dev                env=dev,app=blackpoint-api
# blackpoint-api-prd                env=prd,app=blackpoint-api
# notifier-dev                      env=dev,app=notifier
# notifier-prd                      env=prd,app=notifier
```

## Alternative: Using CNPG Managed Roles

CloudNativePG может управлять ролями декларативно:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
spec:
  managed:
    roles:
      - name: teleport_readonly
        ensure: present
        login: true
        superuser: false
        inRoles:
          - pg_read_all_data
      - name: teleport_readwrite
        ensure: present
        login: true
        superuser: false
        inRoles:
          - pg_read_all_data
          - pg_write_all_data
```

## Next Steps

→ [04-rbac-roles.md](04-rbac-roles.md)
