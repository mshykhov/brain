# Cloudflare Migration to Terraform: Complete Plan

## Current State Analysis

### What Already Exists in Cloudflare (Manual)

| Resource | ID/Value | Status |
|----------|----------|--------|
| Zone | gaynance.com | Active, transferred from Namecheap |
| Nameservers | Cloudflare assigned | Configured at registrar |
| Tunnel | `a20dee6e-21d7-4859-bdd1-d3a276951b09` | Running |
| Tunnel credentials | In Doppler `CF_TUNNEL_CREDENTIALS` | Working |
| DNS (wildcard) | `*.gaynance.com` → tunnel CNAME | Via External-DNS |
| R2 bucket | `cnpg-backups` | Active |
| Cache Rule | Bypass for sw.js | Manual in dashboard |
| API Token | In Doppler `CF_API_TOKEN` | For External-DNS |

### What K8s/ArgoCD Currently Manages

| Component | How it works |
|-----------|--------------|
| cloudflared deployment | Helm chart, 2 replicas |
| Tunnel config (ingress rules) | ConfigMap in K8s |
| DNS records for services | External-DNS creates automatically |
| Tunnel credentials | ExternalSecret from Doppler |

---

## Division of Responsibilities

```
┌─────────────────────────────────────────────────────────────────┐
│                    MANUAL (One-time, done)                      │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • Zone creation (gaynance.com)                            │  │
│  │ • Nameserver configuration at registrar                   │  │
│  │ • SSL/TLS mode selection                                  │  │
│  │ • Account setup                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TERRAFORM (Static resources)                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • Zero Trust Tunnel (import existing)                     │  │
│  │ • R2 buckets (import cnpg-backups, create terraform-state)│  │
│  │ • Cache Rules (sw.js bypass)                              │  │
│  │ • Zone settings (optional: SSL mode, security level)      │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ARGOCD/K8S (Dynamic resources)               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ • cloudflared Deployment (Helm chart)                     │  │
│  │ • Tunnel ingress config (ConfigMap)                       │  │
│  │ • DNS records for services (External-DNS)                 │  │
│  │ • Tunnel credentials (ExternalSecret → Doppler)           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## What Terraform Will Manage

### 1. Zero Trust Tunnel

```hcl
resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "smhomelab-tunnel"
  secret     = base64encode(random_password.tunnel_secret.result)
}
```

**Import existing:**
```bash
terraform import cloudflare_zero_trust_tunnel_cloudflared.main \
  <account_id>/a20dee6e-21d7-4859-bdd1-d3a276951b09
```

**Important:** After import, Terraform manages the tunnel. But:
- Tunnel credentials stay in Doppler
- cloudflared deployment stays in K8s
- Ingress rules stay in K8s ConfigMap

### 2. R2 Buckets

```hcl
resource "cloudflare_r2_bucket" "cnpg_backups" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "WEUR"
}

resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = "terraform-state"
  location   = "WEUR"
}
```

**Import existing:**
```bash
terraform import cloudflare_r2_bucket.cnpg_backups \
  <account_id>/cnpg-backups
```

### 3. Cache Rules (for sw.js)

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
    expression  = "(http.request.uri.path eq \"/sw.js\")"
    description = "Bypass cache for Service Worker"
    enabled     = true
  }
}
```

---

## What Terraform Will NOT Manage

| Resource | Why | Who Manages |
|----------|-----|-------------|
| DNS records for services | Dynamic, change with deploys | External-DNS |
| Tunnel ingress rules | Part of K8s config | K8s ConfigMap |
| cloudflared deployment | K8s workload | ArgoCD Helm |
| Tunnel credentials secret | Already in Doppler | ExternalSecret |
| Zone (gaynance.com) | Already exists | Manual (done) |
| Nameservers | Registrar setting | Manual (done) |

---

## Migration Steps

### Phase 0: Prerequisites (Manual, 15 min)

#### Step 0.1: Create R2 bucket for Terraform state

**In Cloudflare Dashboard:**
1. Go to **R2** → **Create bucket**
2. Name: `terraform-state`
3. Location: `Western Europe (WEUR)`
4. Create bucket

#### Step 0.2: Create R2 API Token

**In Cloudflare Dashboard:**
1. Go to **R2** → **Manage R2 API Tokens**
2. **Create API Token**
3. Permissions: **Object Read & Write**
4. Specify buckets: **All buckets** (or just terraform-state)
5. Save:
   - Access Key ID → GitHub Secret `R2_ACCESS_KEY_ID`
   - Secret Access Key → GitHub Secret `R2_SECRET_ACCESS_KEY`

#### Step 0.3: Get Cloudflare IDs

**In Cloudflare Dashboard:**

| Value | Where to find |
|-------|---------------|
| Account ID | Any zone → Overview → right sidebar → Account ID |
| Zone ID | gaynance.com → Overview → right sidebar → Zone ID |
| Tunnel ID | Zero Trust → Networks → Tunnels → smhomelab-tunnel |

**Save for later:**
```
Account ID: ____________________________
Zone ID: ____________________________
Tunnel ID: a20dee6e-21d7-4859-bdd1-d3a276951b09 (known)
```

#### Step 0.4: Create Cloudflare API Token

**In Cloudflare Dashboard:**
1. Go to **My Profile** → **API Tokens**
2. **Create Token** → **Custom token**
3. Name: `Terraform`
4. Permissions:
   - Account → Cloudflare Tunnel → Edit
   - Account → R2 Storage → Edit
   - Zone → Cache Rules → Edit
   - Zone → Zone Settings → Read (optional, for zone data source)
5. Zone Resources: Include → Specific zone → gaynance.com
6. Account Resources: Include → Specific account → your account
7. Create Token
8. Save token → GitHub Secret `CF_API_TOKEN`

---

### Phase 1: Prepare Terraform Code (No Changes Yet)

#### Step 1.1: Create directory structure

```
infrastructure/
└── terraform/
    ├── versions.tf
    ├── main.tf
    ├── variables.tf
    ├── tunnel.tf
    ├── r2.tf
    ├── cache_rules.tf
    └── outputs.tf
```

#### Step 1.2: Write Terraform code

**versions.tf:**
```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}
```

**main.tf:**
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

# Data source to get zone info
data "cloudflare_zone" "main" {
  zone_id = var.cloudflare_zone_id
}
```

**variables.tf:**
```hcl
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for gaynance.com"
}

variable "tunnel_id" {
  type        = string
  default     = "a20dee6e-21d7-4859-bdd1-d3a276951b09"
  description = "Existing tunnel ID to import"
}
```

**tunnel.tf:**
```hcl
# Import existing tunnel - DO NOT recreate
# Import command: terraform import cloudflare_zero_trust_tunnel_cloudflared.main <account_id>/<tunnel_id>

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "smhomelab-tunnel"
  # secret is managed externally (Doppler), don't change
}
```

**r2.tf:**
```hcl
# Import: terraform import cloudflare_r2_bucket.cnpg_backups <account_id>/cnpg-backups
resource "cloudflare_r2_bucket" "cnpg_backups" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "WEUR"
}

# Already created manually in Phase 0
resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = "terraform-state"
  location   = "WEUR"
}
```

**cache_rules.tf:**
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
    description = "Bypass cache for Service Worker files"
    enabled     = true
  }
}
```

**outputs.tf:**
```hcl
output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.id
  description = "Tunnel ID"
}

output "tunnel_cname" {
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  description = "Tunnel CNAME target for DNS"
}

output "zone_name" {
  value       = data.cloudflare_zone.main.name
  description = "Zone name"
}
```

---

### Phase 2: Import Existing Resources

**CRITICAL: This phase imports existing resources. NO DELETION.**

#### Step 2.1: Initialize Terraform

```bash
cd infrastructure/terraform

export AWS_ACCESS_KEY_ID="<R2_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<R2_SECRET_ACCESS_KEY>"

terraform init
```

#### Step 2.2: Import existing tunnel

```bash
export TF_VAR_cloudflare_api_token="<CF_API_TOKEN>"
export TF_VAR_cloudflare_account_id="<ACCOUNT_ID>"
export TF_VAR_cloudflare_zone_id="<ZONE_ID>"

terraform import cloudflare_zero_trust_tunnel_cloudflared.main \
  ${TF_VAR_cloudflare_account_id}/a20dee6e-21d7-4859-bdd1-d3a276951b09
```

#### Step 2.3: Import existing R2 bucket

```bash
terraform import cloudflare_r2_bucket.cnpg_backups \
  ${TF_VAR_cloudflare_account_id}/cnpg-backups

terraform import cloudflare_r2_bucket.terraform_state \
  ${TF_VAR_cloudflare_account_id}/terraform-state
```

#### Step 2.4: Plan and verify

```bash
terraform plan
```

**Expected output:**
- Tunnel: No changes (imported)
- R2 buckets: No changes (imported)
- Cache Rules: **Will be created** (new)

**If plan shows DESTROY for tunnel - STOP!**
Something is wrong. Check:
- Import was successful
- Resource name matches
- account_id is correct

---

### Phase 3: Delete Manual Cache Rule

**ONLY after Terraform plan shows cache rule will be created:**

1. Go to Cloudflare Dashboard
2. gaynance.com → **Caching** → **Cache Rules**
3. Find "Bypass cache for Service Worker" rule
4. **Delete** the rule

**Why:** Terraform will create its own cache rule. Duplicate rules cause conflicts.

---

### Phase 4: Apply Terraform

```bash
terraform apply
```

**Expected changes:**
- Cache rule: Created
- Everything else: No changes

---

### Phase 5: Setup GitHub Actions

Add GitHub Secrets:
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CF_API_TOKEN`
- `CF_ACCOUNT_ID`
- `CF_ZONE_ID`

Commit and push terraform code.

---

## Order of Operations Summary

```
1. [Manual] Create terraform-state R2 bucket
2. [Manual] Create R2 API token
3. [Manual] Create Cloudflare API token
4. [Manual] Get Account ID and Zone ID
5. [Code]   Write Terraform files
6. [TF]     terraform init
7. [TF]     terraform import tunnel
8. [TF]     terraform import R2 buckets
9. [TF]     terraform plan (verify NO destroys)
10. [Manual] Delete existing cache rule from dashboard
11. [TF]     terraform apply
12. [Manual] Add GitHub Secrets
13. [Code]   Commit and push
```

---

## What NOT to Delete Before Terraform

| Resource | Can Delete? | When |
|----------|-------------|------|
| Cache Rule | Yes | After TF plan confirms creation |
| Tunnel | **NO** | Import, never delete |
| DNS records | **NO** | External-DNS manages |
| R2 buckets | **NO** | Import, never delete |
| Zone settings | **NO** | Don't touch |

---

## Rollback Plan

### If something goes wrong with tunnel:

```bash
# Remove from TF state (doesn't delete in CF)
terraform state rm cloudflare_zero_trust_tunnel_cloudflared.main
```

Tunnel continues working, just not managed by TF.

### If cache rule breaks:

```bash
# Remove from TF state
terraform state rm cloudflare_ruleset.cache_rules

# Recreate manually in dashboard
```

---

## Post-Migration State

| Resource | Before | After |
|----------|--------|-------|
| Tunnel | Manual | Terraform (imported) |
| Tunnel credentials | Doppler | Doppler (unchanged) |
| Tunnel deployment | ArgoCD | ArgoCD (unchanged) |
| Tunnel ingress | K8s ConfigMap | K8s ConfigMap (unchanged) |
| DNS records | External-DNS | External-DNS (unchanged) |
| Cache Rules | Manual | Terraform |
| R2 cnpg-backups | Manual | Terraform (imported) |
| R2 terraform-state | Manual | Terraform (imported) |

---

## Disaster Recovery After Migration

### Recreate tunnel from scratch:

```bash
cd infrastructure/terraform

# Remove old tunnel from state
terraform state rm cloudflare_zero_trust_tunnel_cloudflared.main

# Modify tunnel.tf to generate new secret
# Apply creates new tunnel
terraform apply

# Get new credentials
terraform output -json

# Update Doppler CF_TUNNEL_CREDENTIALS with new value
# Restart cloudflared pods
kubectl rollout restart deployment cloudflared -n cloudflare
```

---

## Sources

- [Cloudflare: Deploy Tunnels with Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [cf-terraforming Tool](https://github.com/cloudflare/cf-terraforming)
- [Cloudflare: Add Site to Cloudflare](https://developers.cloudflare.com/fundamentals/setup/manage-domains/add-site/)
- [Cloudflare: Cache Rules](https://developers.cloudflare.com/cache/how-to/cache-rules/)
- [Terraform: cloudflare_ruleset](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/ruleset)
