# Step 1: Cloudflare Migration to Terraform (Option B - Remotely Managed)

Full tunnel control via Terraform. Ingress config in Cloudflare API, not K8s ConfigMap.

## Current State

| Resource | Value | Status |
|----------|-------|--------|
| Zone | gaynance.com | Active |
| Tunnel | `a20dee6e-21d7-4859-bdd1-d3a276951b09` | Running (locally-managed) |
| Tunnel credentials | Doppler `CF_TUNNEL_CREDENTIALS` | JSON file |
| R2 bucket | `cnpg-backups` | Active |
| Cache Rule | Bypass for sw.js | Manual |

## Target State

| Resource | Managed By | Notes |
|----------|------------|-------|
| Tunnel | Terraform | Import existing |
| Tunnel ingress config | Terraform | Move from K8s ConfigMap |
| R2 buckets | Terraform | Import existing |
| Cache Rules | Terraform | New |
| cloudflared deployment | ArgoCD | Changed: use `--token` |
| Tunnel token | Doppler | Changed: token instead of JSON |

---

## Architecture After Migration

```
┌─────────────────────────────────────────────────────────────────┐
│                         TERRAFORM                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ cloudflare_zero_trust_tunnel_cloudflared (tunnel)         │  │
│  │ cloudflare_zero_trust_tunnel_cloudflared_config (ingress) │  │
│  │ cloudflare_r2_bucket (cnpg-backups, terraform-state)      │  │
│  │ cloudflare_ruleset (cache rules)                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                    output: tunnel_token                          │
│                              ▼                                   │
│                     Manual paste (once)                          │
│                              ▼                                   │
│                          Doppler                                 │
│                    CF_TUNNEL_TOKEN (new)                         │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼ ExternalSecret
┌─────────────────────────────────────────────────────────────────┐
│                         ARGOCD                                   │
│  cloudflare-tunnel Helm (changed):                              │
│  - Deployment: cloudflared tunnel run --token $TUNNEL_TOKEN     │
│  - NO ConfigMap (removed)                                        │
│  - NO credentials.json (removed)                                 │
│                                                                  │
│  protected-services, service-ingress: UNCHANGED                  │
│  external-dns: UNCHANGED                                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Migration Order (Zero Downtime)

```
Phase 0: Prerequisites (manual)
    │
    ▼
Phase 1: Create Terraform code
    │
    ▼
Phase 2: Import existing tunnel (NO CHANGES to running tunnel)
    │
    ▼
Phase 3: Add tunnel config to Terraform
    │
    ▼
Phase 4: Apply Terraform (creates config in CF API)
    │     ↓
    │   Tunnel now has BOTH configs (local + remote)
    │   Traffic still works via local config
    │
    ▼
Phase 5: Update Doppler (CF_TUNNEL_CREDENTIALS → CF_TUNNEL_TOKEN)
    │
    ▼
Phase 6: Update ArgoCD Helm chart (--config → --token)
    │     ↓
    │   cloudflared restarts, reads remote config
    │   SHORT RESTART (~10 sec, 2 replicas = rolling)
    │
    ▼
Phase 7: Cleanup old K8s resources
    │
    ▼
Phase 8: Delete manual cache rule, apply TF
    │
    ▼
Done ✓
```

---

## Phase 0: Prerequisites (15 min)

### 0.1 Create R2 bucket for Terraform state

**Cloudflare Dashboard → R2 → Create bucket**
- Name: `terraform-state`
- Location: `Western Europe (WEUR)`

### 0.2 Create R2 API Token

**Cloudflare Dashboard → R2 → Manage R2 API Tokens → Create**
- Permissions: Object Read & Write
- Buckets: All buckets
- Save:
  - Access Key ID → `R2_ACCESS_KEY_ID`
  - Secret Access Key → `R2_SECRET_ACCESS_KEY`

### 0.3 Get Cloudflare IDs

| Value | Where |
|-------|-------|
| Account ID | Any zone → Overview → right sidebar |
| Zone ID | gaynance.com → Overview → right sidebar |
| Tunnel ID | `a20dee6e-21d7-4859-bdd1-d3a276951b09` |

### 0.4 Create Cloudflare API Token

**My Profile → API Tokens → Create Token → Custom**

Permissions:
- Account → Cloudflare Tunnel → Edit
- Account → R2 Storage → Edit
- Zone → Cache Rules → Edit
- Zone → Zone Settings → Read

Zone Resources: gaynance.com only

Save → `CF_API_TOKEN`

---

## Phase 1: Create Terraform Code

### Directory structure

```
infrastructure/terraform/
├── versions.tf
├── main.tf
├── variables.tf
├── tunnel.tf
├── r2.tf
├── cache_rules.tf
└── outputs.tf
```

### versions.tf

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}
```

### main.tf

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "cloudflare.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://1873df9e0a22e919beb083244b6eda83.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

data "cloudflare_zone" "main" {
  zone_id = var.cloudflare_zone_id
}
```

### variables.tf

```hcl
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "domain" {
  type    = string
  default = "gaynance.com"
}
```

### tunnel.tf

```hcl
# Tunnel resource
# Import: terraform import cloudflare_zero_trust_tunnel_cloudflared.main <account_id>/a20dee6e-21d7-4859-bdd1-d3a276951b09

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "smhomelab-tunnel"
}

# Tunnel ingress configuration (remotely-managed)
# This replaces K8s ConfigMap
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config {
    ingress_rule {
      service = "http://nginx-ingress-ingress-nginx-controller.ingress-nginx.svc.cluster.local:80"
    }
  }
}
```

### r2.tf

```hcl
# Import: terraform import cloudflare_r2_bucket.cnpg_backups <account_id>/cnpg-backups
resource "cloudflare_r2_bucket" "cnpg_backups" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "WEUR"
}

# Import: terraform import cloudflare_r2_bucket.terraform_state <account_id>/terraform-state
resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = "terraform-state"
  location   = "WEUR"
}
```

### cache_rules.tf

```hcl
resource "cloudflare_ruleset" "cache_rules" {
  zone_id     = var.cloudflare_zone_id
  name        = "Cache rules"
  description = "Cache rules for gaynance.com"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action = "set_cache_settings"
    action_parameters {
      cache = false
    }
    expression  = "(http.request.uri.path eq \"/sw.js\") or (http.request.uri.path eq \"/service-worker.js\")"
    description = "Bypass cache for Service Worker"
    enabled     = true
  }
}
```

### outputs.tf

```hcl
output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

output "tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.main.tunnel_token
  sensitive = true
}

output "tunnel_cname" {
  value = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
}
```

---

## Phase 2: Import Existing Tunnel

**CRITICAL: This imports existing tunnel. NO recreation, NO downtime.**

```bash
cd infrastructure/terraform

# Set credentials
export AWS_ACCESS_KEY_ID="<R2_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<R2_SECRET_ACCESS_KEY>"
export TF_VAR_cloudflare_api_token="<CF_API_TOKEN>"
export TF_VAR_cloudflare_account_id="<ACCOUNT_ID>"
export TF_VAR_cloudflare_zone_id="<ZONE_ID>"

# Init
terraform init

# Import tunnel ONLY (not config yet)
terraform import cloudflare_zero_trust_tunnel_cloudflared.main \
  ${TF_VAR_cloudflare_account_id}/a20dee6e-21d7-4859-bdd1-d3a276951b09

# Import R2 buckets
terraform import cloudflare_r2_bucket.cnpg_backups \
  ${TF_VAR_cloudflare_account_id}/cnpg-backups

terraform import cloudflare_r2_bucket.terraform_state \
  ${TF_VAR_cloudflare_account_id}/terraform-state
```

---

## Phase 3: Plan and Verify

```bash
terraform plan
```

**Expected output:**
- `cloudflare_zero_trust_tunnel_cloudflared.main`: No changes (imported)
- `cloudflare_r2_bucket.*`: No changes (imported)
- `cloudflare_zero_trust_tunnel_cloudflared_config.main`: **Will be created**
- `cloudflare_ruleset.cache_rules`: Will be created (ignore for now)

**STOP if plan shows:**
- Tunnel: replace or destroy → Something wrong, check import
- R2: destroy → Check bucket names

---

## Phase 4: Apply Tunnel Config

```bash
# Apply ONLY tunnel and config (skip cache rules for now)
terraform apply -target=cloudflare_zero_trust_tunnel_cloudflared.main \
                -target=cloudflare_zero_trust_tunnel_cloudflared_config.main \
                -target=cloudflare_r2_bucket.cnpg_backups \
                -target=cloudflare_r2_bucket.terraform_state
```

**What happens:**
- Tunnel config created in Cloudflare API
- Tunnel now has BOTH: local (K8s ConfigMap) + remote (CF API)
- cloudflared still uses local config → **NO IMPACT**

**Verify in Cloudflare Dashboard:**
1. Zero Trust → Networks → Tunnels
2. Click on smhomelab-tunnel
3. Should see "Public Hostnames" tab with ingress rule

---

## Phase 5: Update Doppler

### 5.1 Get tunnel token

```bash
terraform output -raw tunnel_token
```

Copy the token (long base64 string).

### 5.2 Add new secret to Doppler

**Doppler → smhomelab → shared:**
1. Add new secret: `CF_TUNNEL_TOKEN` = (paste token)
2. Keep `CF_TUNNEL_CREDENTIALS` for now (rollback safety)

---

## Phase 6: Update ArgoCD Helm Chart

### 6.1 Update ExternalSecret

**File:** `infrastructure/charts/credentials/templates/cloudflare.yaml`

Add new secret:
```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflare-tunnel-token
  namespace: cloudflare
spec:
  refreshInterval: 5m
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: tunnel-token
    creationPolicy: Owner
  data:
    - secretKey: token
      remoteRef:
        key: CF_TUNNEL_TOKEN
```

### 6.2 Update Deployment

**File:** `infrastructure/charts/cloudflare-tunnel/templates/deployment.yaml`

Change from:
```yaml
args:
  - tunnel
  - --config
  - /etc/cloudflared/config/config.yaml
  - run
volumeMounts:
  - name: config
    mountPath: /etc/cloudflared/config
  - name: creds
    mountPath: /etc/cloudflared/creds
volumes:
  - name: config
    configMap:
      name: cloudflared-config
  - name: creds
    secret:
      secretName: tunnel-credentials
```

To:
```yaml
args:
  - tunnel
  - run
  - --token
  - $(TUNNEL_TOKEN)
env:
  - name: TUNNEL_TOKEN
    valueFrom:
      secretKeyRef:
        name: tunnel-token
        key: token
# Remove volumeMounts and volumes for config and creds
```

### 6.3 Delete ConfigMap template

**Delete file:** `infrastructure/charts/cloudflare-tunnel/templates/configmap.yaml`

### 6.4 Commit and push

```bash
git add infrastructure/charts/
git commit -m "feat: migrate cloudflare tunnel to remotely-managed"
git push
```

### 6.5 Wait for ArgoCD sync

ArgoCD will:
1. Create new ExternalSecret
2. Wait for tunnel-token secret
3. Update Deployment
4. Rolling restart (2 replicas → zero downtime)

**Monitor:**
```bash
kubectl get pods -n cloudflare -w
```

---

## Phase 7: Cleanup

### 7.1 Delete old ExternalSecret from chart

Remove `cloudflare-tunnel-credentials` ExternalSecret from credentials chart.

### 7.2 Delete old Doppler secret

**Doppler → smhomelab → shared:**
- Delete `CF_TUNNEL_CREDENTIALS` (no longer needed)

### 7.3 Commit cleanup

```bash
git add infrastructure/charts/credentials/
git commit -m "chore: remove old tunnel credentials"
git push
```

---

## Phase 8: Apply Cache Rules

### 8.1 Delete manual cache rule

**Cloudflare Dashboard → gaynance.com → Caching → Cache Rules**
- Delete "Bypass cache for Service Worker"

### 8.2 Apply full Terraform

```bash
terraform apply
```

---

## Verification Checklist

| Check | Command/Action |
|-------|----------------|
| Tunnel running | `kubectl get pods -n cloudflare` |
| Tunnel connected | CF Dashboard → Zero Trust → Tunnels → Status: Healthy |
| Ingress config | CF Dashboard → Tunnel → Public Hostnames |
| DNS working | `curl -I https://argocd.gaynance.com` |
| Cache rule | `curl -I https://app.gaynance.com/sw.js` → `cf-cache-status: DYNAMIC` |

---

## Rollback Plan

### If tunnel breaks after Phase 6:

```bash
# Revert ArgoCD changes
git revert HEAD
git push

# cloudflared will restart with old config
```

### If need to completely rollback:

```bash
# Remove tunnel config from TF state (doesn't delete from CF)
terraform state rm cloudflare_zero_trust_tunnel_cloudflared_config.main

# Revert all ArgoCD changes
git revert HEAD~3..HEAD
git push
```

---

## Files Changed Summary

| File | Action |
|------|--------|
| `infrastructure/terraform/*` | Created (new) |
| `charts/credentials/templates/cloudflare.yaml` | Add tunnel-token ExternalSecret |
| `charts/cloudflare-tunnel/templates/deployment.yaml` | Change to --token |
| `charts/cloudflare-tunnel/templates/configmap.yaml` | Delete |
| `charts/cloudflare-tunnel/values.yaml` | Remove tunnel.uuid |

---

## Sources

- [Cloudflare: Remotely-managed tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/remote-management/)
- [Cloudflare: Tunnel run parameters](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-run-parameters/)
- [Cloudflare: Deploy tunnels with Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [Terraform: cloudflare_zero_trust_tunnel_cloudflared](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared)
- [Terraform: cloudflare_zero_trust_tunnel_cloudflared_config](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared_config)
