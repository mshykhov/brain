# PKI Engine Configuration (GitOps)

PKI Engine настраивается автоматически через `vault-config` Helm chart.

## 1. ArgoCD Application

`infrastructure/apps/templates/core/vault-config.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vault-config
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "6"  # After Vault (wave 5)
spec:
  project: infrastructure
  source:
    repoURL: git@github.com:mshykhov/smhomelab-infrastructure.git
    targetRevision: master
    path: charts/vault-config
    helm:
      valuesObject:
        oidc:
          enabled: true
          discoveryUrl: "https://login.gaynance.com/"
          clientId: "Y8QpXWQDlKjhTUMaDvnkb5sbsufiHLyP"
        tailnet: trout-paradise
  destination:
    server: https://kubernetes.default.svc
    namespace: vault
```

## 2. Vault Config Values

`infrastructure/charts/vault-config/values.yaml`:

```yaml
vault:
  address: "http://vault.vault.svc.cluster.local:8200"

pki:
  root:
    commonName: "smhomelab-root-ca"
    ttl: "87600h"  # 10 years

  intermediate:
    commonName: "smhomelab-intermediate-ca"
    ttl: "43800h"  # 5 years

  # PKI Roles for certificate issuance
  roles:
    db-readonly:
      allow_any_name: true
      enforce_hostnames: false
      allow_ip_sans: false
      server_flag: false
      client_flag: true
      max_ttl: "2190h"  # 3 months

    db-readwrite:
      allow_any_name: true
      enforce_hostnames: false
      allow_ip_sans: false
      server_flag: false
      client_flag: true
      max_ttl: "2190h"

    db-admin:
      allow_any_name: true
      enforce_hostnames: false
      allow_ip_sans: false
      server_flag: false
      client_flag: true
      max_ttl: "2190h"
```

## 3. Configuration Job

Chart использует Job с hash-based именем для идемпотентного применения конфигурации:

```yaml
# templates/job.yaml
{{- $configHash := include (print $.Template.BasePath "/configmap.yaml") . | sha256sum | trunc 8 }}
apiVersion: batch/v1
kind: Job
metadata:
  name: vault-config-{{ $configHash }}
  namespace: vault
  annotations:
    argocd.argoproj.io/sync-options: Delete=true
```

При изменении конфигурации создаётся новый Job, который применяет изменения.

## 4. What Job Configures

Script в ConfigMap настраивает:

1. **PKI Root CA** - enables pki/, generates root CA
2. **PKI Intermediate CA** - enables pki_int/, generates intermediate CA
3. **PKI Roles** - creates roles for certificate issuance
4. **Vault Policies** - creates access policies
5. **OIDC Auth** - configures Auth0 integration
6. **External Groups** - maps Auth0 roles to Vault policies

## 5. Export CA Certificate

После успешной настройки PKI, экспортируем CA certificate в Doppler:

```bash
# Get CA certificate
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault read -field=certificate pki_int/cert/ca"

# Copy output to Doppler (shared) as VAULT_CA_CERT
```

## 6. Verify PKI Setup

```bash
# Check PKI engines
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault secrets list"

# Check roles
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault list pki_int/roles"

# Test certificate issuance
ssh ovh-ts "sudo kubectl exec -n vault vault-0 -- vault write -format=json pki_int/issue/db-readonly common_name=test ttl=1h"
```

## 7. Adding New PKI Roles

Для добавления новой роли:

1. Добавить в `values.yaml`:
   ```yaml
   pki:
     roles:
       db-new-role:
         allow_any_name: true
         # ... other settings
   ```

2. Push to git
3. ArgoCD создаст новый Job
4. Job применит новую роль

## Next Steps

→ [03-auth0-oidc.md](03-auth0-oidc.md)
