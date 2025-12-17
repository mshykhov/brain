# Step 1: Cloudflare Migration to Terraform

## Current State

| Resource | ID/Value | Status |
|----------|----------|--------|
| Zone | gaynance.com | Active (transferred from Namecheap) |
| Tunnel | `a20dee6e-21d7-4859-bdd1-d3a276951b09` | Running |
| Tunnel credentials | Doppler `CF_TUNNEL_CREDENTIALS` | Working |
| R2 bucket | `cnpg-backups` | Active |
| Cache Rule | Bypass for sw.js | Manual in dashboard |

---

## Division of Responsibilities

```
┌─────────────────────────────────────────────────────────────────┐
│                    MANUAL (One-time, already done)              │
│  • Zone creation (gaynance.com)                                 │
│  • Nameserver configuration at registrar                        │
│  • SSL/TLS mode selection                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TERRAFORM (Static resources)                 │
│  • Zero Trust Tunnel (import existing)                          │
│  • R2 buckets (import cnpg-backups, create terraform-state)     │
│  • Cache Rules (sw.js bypass)                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ARGOCD/K8S (Dynamic, unchanged)              │
│  • cloudflared Deployment (Helm chart)                          │
│  • Tunnel ingress config (ConfigMap)                            │
│  • DNS records for services (External-DNS)                      │
│  • Tunnel credentials (ExternalSecret → Doppler)                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Migration Steps

### Phase 0: Prerequisites (Manual, 15 min)

#### 0.1 Create R2 bucket for Terraform state

**Cloudflare Dashboard → R2 → Create bucket**
- Name: `terraform-state`
- Location: `Western Europe (WEUR)`

#### 0.2 Create R2 API Token

**Cloudflare Dashboard → R2 → Manage R2 API Tokens → Create**
- Permissions: Object Read & Write
- Buckets: All buckets
- Save:
  - Access Key ID → `R2_ACCESS_KEY_ID`
  - Secret Access Key → `R2_SECRET_ACCESS_KEY`

#### 0.3 Get Cloudflare IDs

| Value | Where |
|-------|-------|
| Account ID | Any zone → Overview → right sidebar |
| Zone ID | gaynance.com → Overview → right sidebar |
| Tunnel ID | `a20dee6e-21d7-4859-bdd1-d3a276951b09` (known) |

#### 0.4 Create Cloudflare API Token

**My Profile → API Tokens → Create Token → Custom**

Permissions:
- Account → Cloudflare Tunnel → Edit
- Account → R2 Storage → Edit
- Zone → Cache Rules → Edit
- Zone → Zone Settings → Read

Zone Resources: gaynance.com only

Save token → `CF_API_TOKEN`

---

### Phase 1: Create Terraform Code

#### Directory structure

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

#### versions.tf

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

#### main.tf

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

#### variables.tf

```hcl
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
}

variable "cloudflare_zone_id" {
  type        = string
}
```

#### tunnel.tf

```hcl
# Import: terraform import cloudflare_zero_trust_tunnel_cloudflared.main <account_id>/a20dee6e-21d7-4859-bdd1-d3a276951b09

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "smhomelab-tunnel"
}
```

#### r2.tf

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

#### cache_rules.tf

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

#### outputs.tf

```hcl
output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

output "tunnel_cname" {
  value = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
}
```

---

### Phase 2: Import Existing Resources

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

# Import tunnel
terraform import cloudflare_zero_trust_tunnel_cloudflared.main \
  ${TF_VAR_cloudflare_account_id}/a20dee6e-21d7-4859-bdd1-d3a276951b09

# Import R2 buckets
terraform import cloudflare_r2_bucket.cnpg_backups \
  ${TF_VAR_cloudflare_account_id}/cnpg-backups

terraform import cloudflare_r2_bucket.terraform_state \
  ${TF_VAR_cloudflare_account_id}/terraform-state

# Plan - verify NO DESTROYS
terraform plan
```

**Expected:** Tunnel and R2 = no changes, Cache Rule = will be created

---

### Phase 3: Delete Manual Cache Rule

**ONLY after terraform plan confirms cache rule creation:**

1. Cloudflare Dashboard → gaynance.com → Caching → Cache Rules
2. Delete "Bypass cache for Service Worker" rule

---

### Phase 4: Apply

```bash
terraform apply
```

---

### Phase 5: GitHub Actions Setup

Add secrets to repository:
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `CF_API_TOKEN`
- `CF_ACCOUNT_ID`
- `CF_ZONE_ID`

Commit and push terraform code.

---

## Order Summary

```
1. [Manual] Create terraform-state R2 bucket
2. [Manual] Create R2 API token → save keys
3. [Manual] Create CF API token → save token
4. [Manual] Get Account ID and Zone ID
5. [Code]   Create terraform files
6. [TF]     terraform init
7. [TF]     terraform import (tunnel, R2 buckets)
8. [TF]     terraform plan → verify NO DESTROYS
9. [Manual] Delete manual cache rule
10. [TF]    terraform apply
11. [Manual] Add GitHub Secrets
12. [Code]  Commit and push
```

---

## What NOT to Delete

| Resource | Delete? | When |
|----------|---------|------|
| Cache Rule | Yes | After TF plan confirms creation |
| Tunnel | **NO** | Import only |
| R2 buckets | **NO** | Import only |
| DNS records | **NO** | External-DNS manages |

---

## Rollback

```bash
# If tunnel breaks - remove from state (doesn't delete in CF)
terraform state rm cloudflare_zero_trust_tunnel_cloudflared.main

# If cache rule breaks
terraform state rm cloudflare_ruleset.cache_rules
# Recreate manually in dashboard
```

---

## Sources

- [Cloudflare Tunnel Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [cf-terraforming](https://github.com/cloudflare/cf-terraforming)
- [Cloudflare Cache Rules](https://developers.cloudflare.com/cache/how-to/cache-rules/)
