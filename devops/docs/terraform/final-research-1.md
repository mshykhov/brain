# Terraform Integration: Final Research & Critical Analysis

## Executive Summary

**Verdict:** Terraform добавляет ценность, но текущие документы переусложняют scope. Реальная польза — только Cloudflare. Auth0 — опционально. Doppler/Tailscale — overkill.

---

## Critical Analysis of Existing Docs

### 00-research.md — Issues

| Claim | Reality |
|-------|---------|
| "Doppler projects created manually" = problem | **False.** Doppler UI работает отлично, проекты создаются 1 раз |
| "Tailscale ACLs via Terraform" | **Overkill.** ACLs меняются раз в год |
| "Tofu-Controller as alternative" | **Risky.** Weaveworks закрылась, community support uncertain |
| 4 провайдера (CF, Auth0, Doppler, TS) | **Too many.** Каждый добавляет complexity |

### 01-setup-guide.md — Issues

| Claim | Reality |
|-------|---------|
| "tf-controller requires Flux" | **Partially true.** Tofu-Controller работает standalone, но требует Flux CRDs |
| Directory structure with shared/dev/prd | **Overcomplicated** для 2 environments |
| Vault integration in workflow | **Adds dependency.** TF → Vault → External Secrets = 3 points of failure |

### 02-auth0-bootstrap.md — Issues

| Claim | Reality |
|-------|---------|
| M2M permissions list | **Too broad.** `read:connections`, `create:connections` не нужны |
| "Terraform manages everything else" | **Unrealistic.** Некоторые Auth0 settings лучше в UI |
| Vault as secrets intermediary | **Questionable.** Зачем TF → Vault если есть TF → Doppler напрямую? |

---

## Real Problems to Solve

### Actually Painful (Worth Terraform)

| Problem | Frequency | Impact |
|---------|-----------|--------|
| Cloudflare tunnel recreation | Rare but critical | High — DR blocker |
| DNS records management | Monthly | Medium — manual error risk |
| R2 bucket creation | Once per env | Low but nice to have |

### Not Actually Painful (Skip Terraform)

| "Problem" | Reality |
|-----------|---------|
| Doppler project setup | Done once, never touched |
| Tailscale ACLs | Changed maybe yearly |
| Auth0 apps | 3-4 apps total, rarely change |

---

## Honest ROI Analysis

### Investment Required

| Task | Time |
|------|------|
| Learn Terraform basics | 4-8 hours |
| Set up state backend (R2) | 2 hours |
| Write Cloudflare module | 4 hours |
| Write Auth0 module | 6 hours |
| GitHub Actions setup | 2 hours |
| Testing & debugging | 8 hours |
| **Total** | **26-30 hours** |

### Return

| Benefit | Actual Time Saved |
|---------|-------------------|
| Cloudflare tunnel recreation | 2 hours → 5 min (saves 1.9h per incident) |
| DNS changes | 10 min → 2 min (saves 8 min per change) |
| Auth0 app creation | 30 min → 5 min (saves 25 min per app) |
| Documentation as code | Intangible |

### Break-even

- If tunnel fails once + 10 DNS changes + 2 new apps = ~5 hours saved
- Break-even: **5-6x of above scenarios** to justify 30h investment
- **Realistic payback: 1-2 years**

---

## Recommended Approach: Minimal Viable Terraform

### Phase 1: Cloudflare Only (Do This)

```
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── cloudflare.tf          # Tunnel, DNS, R2
└── terraform.tfvars
```

**Why:**
- Highest ROI — tunnel credentials are DR critical
- Simplest provider — well documented
- Single state file — no environment complexity needed

```hcl
# cloudflare.tf
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket   = "terraform-state"
    key      = "cloudflare.tfstate"
    region   = "auto"
    endpoints = { s3 = "https://<ACCOUNT>.r2.cloudflarestorage.com" }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Tunnel
resource "cloudflare_tunnel" "main" {
  account_id = var.cloudflare_account_id
  name       = "${var.project}-tunnel"
  secret     = random_password.tunnel_secret.result
}

resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

# Tunnel config
resource "cloudflare_tunnel_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.main.id

  config {
    ingress_rule {
      hostname = "*.${var.domain}"
      service  = "http://nginx-ingress-controller.ingress-nginx:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS
resource "cloudflare_record" "tunnel" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  value   = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  proxied = true
}

# R2 buckets
resource "cloudflare_r2_bucket" "cnpg" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "WEUR"
}

resource "cloudflare_r2_bucket" "terraform" {
  account_id = var.cloudflare_account_id
  name       = "terraform-state"
  location   = "WEUR"
}

# Output tunnel token for manual Doppler entry
output "tunnel_token" {
  value     = cloudflare_tunnel.main.tunnel_token
  sensitive = true
}
```

### Phase 2: Auth0 (Maybe Later)

**Only if:**
- Adding new applications frequently (>2/year)
- Complex RBAC with many roles
- Multiple environments with different Auth0 tenants

**Skip if:**
- Stable set of 3-4 applications
- Single Auth0 tenant
- Actions rarely change

### Phase 3: Never Do

| Provider | Why Skip |
|----------|----------|
| Doppler | Works fine, changes never |
| Tailscale | ACLs stable, OAuth keys rotate manually |
| Vault secrets via TF | Use External Secrets directly, less moving parts |

---

## Simplified Architecture

### Before (Overcomplicated)

```
Terraform → Vault → External Secrets → K8s
     ↓
  Doppler
     ↓
  Tailscale
```

### After (Practical)

```
Terraform (Cloudflare only)
     ↓
  Output: tunnel_token
     ↓
  Manual: paste to Doppler (once)
     ↓
External Secrets → K8s
```

**Why manual step is OK:**
- Tunnel token changes never (unless recreation)
- One-time paste vs. maintaining TF → Doppler provider
- Simpler = fewer failure modes

---

## State Management Decision

### Option A: Cloudflare R2 (Recommended)

```hcl
backend "s3" {
  bucket   = "terraform-state"
  key      = "cloudflare.tfstate"
  region   = "auto"
  endpoints = { s3 = "https://<ACCOUNT>.r2.cloudflarestorage.com" }
  # ... skip flags
}
```

**Pros:** Free, already have R2, no new service
**Cons:** No state locking (acceptable for solo/small team)

### Option B: Terraform Cloud Free

**Pros:** State locking, UI, run history
**Cons:** 500 resource limit, another service to manage

### Option C: Local + Git (Don't Do)

**Why not:** No collaboration, no history, secrets in repo risk

**Verdict:** R2 for simplicity. Add TF Cloud only if team grows.

---

## CI/CD: Simplified Workflow

### Single Environment (Recommended for Start)

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  push:
    branches: [master]
    paths: ['terraform/**']
  pull_request:
    paths: ['terraform/**']

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Init
        run: terraform init
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_KEY }}

      - name: Plan
        run: terraform plan -no-color
        env:
          TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
          TF_VAR_cloudflare_account_id: ${{ secrets.CF_ACCOUNT_ID }}
          TF_VAR_cloudflare_zone_id: ${{ secrets.CF_ZONE_ID }}

      - name: Apply
        if: github.ref == 'refs/heads/master' && github.event_name == 'push'
        run: terraform apply -auto-approve
        env:
          TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
          TF_VAR_cloudflare_account_id: ${{ secrets.CF_ACCOUNT_ID }}
          TF_VAR_cloudflare_zone_id: ${{ secrets.CF_ZONE_ID }}
```

### Why Not Matrix for dev/prd

- Cloudflare resources are global (tunnel, DNS)
- No per-environment Cloudflare config needed
- R2 buckets shared across environments
- Simpler workflow = easier debugging

---

## Auth0 Bootstrap: Corrected Permissions

If implementing Auth0 later, minimal permissions:

```
# Actually needed
read:clients
create:clients
update:clients
delete:clients
read:actions
create:actions
update:actions
delete:actions

# NOT needed (remove from 02-auth0-bootstrap.md)
read:connections      # Don't manage connections via TF
create:connections
update:connections
delete:connections
read:client_grants    # Auto-managed by Auth0
create:client_grants
update:client_grants
delete:client_grants
```

---

## Decision Matrix

| Scenario | Recommendation |
|----------|----------------|
| "I want full IaC for everything" | Start with Cloudflare only, prove value first |
| "DR is my main concern" | Cloudflare TF + documented manual steps for rest |
| "I'm adding apps frequently" | Add Auth0 TF after Cloudflare works |
| "Team is growing" | Add TF Cloud for state locking |
| "I want GitOps for TF" | Don't. GitHub Actions is simpler than Tofu-Controller |

---

## Action Items

### Do Now
1. Create `terraform/` folder in infrastructure repo
2. Implement Cloudflare module (tunnel, DNS, R2)
3. Set up R2 bucket for state manually first
4. Add GitHub Actions workflow

### Do Later (If Needed)
5. Add Auth0 module after Cloudflare is stable
6. Consider TF Cloud if team grows

### Never Do
7. Doppler provider — no value
8. Tailscale provider — no value
9. Tofu-Controller — unnecessary complexity
10. Multiple environment directories — YAGNI

---

## Files to Update

| File | Action |
|------|--------|
| `00-research.md` | Keep as historical context |
| `01-setup-guide.md` | Simplify: remove Vault integration, single env |
| `02-auth0-bootstrap.md` | Mark as Phase 2, fix permissions |
| `final-research-1.md` | This file — source of truth |

---

## Sources

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Terraform S3 Backend with R2](https://developers.cloudflare.com/r2/examples/terraform/)
- [GitHub Actions for Terraform](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Auth0 Provider - Minimal Permissions](https://registry.terraform.io/providers/auth0/auth0/latest/docs#authentication)
