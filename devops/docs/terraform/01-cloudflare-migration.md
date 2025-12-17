# Cloudflare Migration to Terraform (Option B - Remotely Managed)

Full tunnel control via Terraform + GitHub Actions CI/CD.

## Current Status

| Resource | Status | Notes |
|----------|--------|-------|
| Tunnel | ✅ Complete | `k8s-tunnel`, token mode |
| Tunnel Config | ✅ Complete | Remotely-managed ingress |
| R2 buckets | ✅ Complete | cnpg-backups (APAC), terraform-state (WEUR) |
| Cache Rules | ✅ Complete | Needed Account Rulesets permission |
| Doppler Integration | ✅ Complete | Auto-writes CF_TUNNEL_TOKEN to shared |
| ExternalSecrets | ✅ Complete | All migrated to doppler-infra-shared |
| cloudflared | ✅ Complete | Token mode, no ConfigMap |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ terraform-apply.yml (reusable)                       │    │
│  │ terraform-cloudflare.yml (caller)                    │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│              on push to terraform/cloudflare/**              │
│                           ▼                                  │
│                    terraform plan/apply                      │
└─────────────────────────────────────────────────────────────┘
                            │
              secrets from Doppler (via GitHub Sync)
                            │
┌─────────────────────────────────────────────────────────────┐
│                      DOPPLER                                 │
│  Project: smhomelub-infra                                   │
│                                                              │
│  cicd (GitHub Actions Sync):                                │
│    - R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY                │
│    - CLOUDFLARE_API_TOKEN, DOPPLER_TOKEN                   │
│                                                              │
│  shared (K8s via ExternalSecrets):                          │
│    - CF_TUNNEL_TOKEN ← Terraform output                    │
│    - CF_API_TOKEN, AUTH0_*, VAULT_*, etc.                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    CLOUDFLARE                                │
│  - Zero Trust Tunnel (k8s-tunnel)                           │
│  - Tunnel Config (ingress rules)                            │
│  - R2 Buckets                                               │
│  - Cache Rules (pending)                                     │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
infrastructure/
├── .github/workflows/
│   ├── terraform-apply.yml      # Reusable workflow
│   └── terraform-cloudflare.yml # Caller for cloudflare
└── terraform/cloudflare/
    ├── versions.tf              # Terraform + providers + R2 backend
    ├── providers.tf             # Cloudflare provider
    ├── variables.tf             # Variable definitions
    ├── terraform.tfvars         # Non-sensitive values (committed)
    ├── tunnel.tf                # Tunnel + import block
    ├── r2.tf                    # R2 buckets + import blocks
    ├── cache.tf                 # Cache rules
    ├── data.tf                  # Data sources
    ├── outputs.tf               # Outputs
    └── .gitignore
```

---

## Key IDs

| Resource | ID |
|----------|-----|
| Account ID | `1873df9e0a22e919beb083244b6eda83` |
| Zone ID (gaynance.com) | `121b1749844fa6c6984c1ccfe3452233` |
| Tunnel ID | `a20dee6e-21d7-4859-bdd1-d3a276951b09` |
| Tunnel Name | `k8s-tunnel` |

---

## API Token Permissions

**Cloudflare API Token "Terraform":**

| Scope | Permission | Access |
|-------|------------|--------|
| Account | Workers R2 Storage | Edit |
| Account | Cloudflare Tunnel | Edit |
| Account | Account Rulesets | Edit |
| Zone | Zone | Edit |
| Zone | Cache Rules | Edit |

**Zone Resources:** gaynance.com only
**Account Resources:** Smhomelub@gmail.com's Account

> **Note:** `Account Rulesets Edit` is required for `cloudflare_ruleset` resource even for zone-level cache rules.

---

## Terraform Code

### versions.tf

```hcl
terraform {
  required_version = ">= 1.14.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    doppler = {
      source  = "DopplerHQ/doppler"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

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
```

### tunnel.tf

```hcl
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "k8s-tunnel"
  secret     = random_id.tunnel_secret.b64_std

  lifecycle {
    ignore_changes = [secret]
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config {
    ingress_rule {
      service = "http://nginx-ingress-ingress-nginx-controller.ingress-nginx.svc.cluster.local:80"
    }
  }
}

# Write tunnel token to Doppler for cloudflared deployment
resource "doppler_secret" "tunnel_token" {
  project = "smhomelub-infra"
  config  = "shared"
  name    = "CF_TUNNEL_TOKEN"
  value   = cloudflare_zero_trust_tunnel_cloudflared.main.tunnel_token
}
```

### r2.tf

```hcl
# CNPG database backups
resource "cloudflare_r2_bucket" "cnpg_backups" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "APAC"
}

# Terraform state backend
# DR: Create bucket manually before first terraform init
import {
  to = cloudflare_r2_bucket.terraform_state
  id = "${var.cloudflare_account_id}/terraform-state"
}

resource "cloudflare_r2_bucket" "terraform_state" {
  account_id = var.cloudflare_account_id
  name       = "terraform-state"
  location   = "WEUR"
}
```

---

## GitHub Actions Workflow

### terraform-apply.yml (reusable)

```yaml
name: Terraform Apply

on:
  workflow_call:
    inputs:
      working_directory:
        required: true
        type: string
      terraform_version:
        required: false
        type: string
        default: "1.14.2"
    # Secrets passed via 'secrets: inherit' from caller

jobs:
  terraform:
    name: Terraform
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ inputs.working_directory }}
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}
      TF_VAR_cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      TF_VAR_doppler_token: ${{ secrets.DOPPLER_TOKEN }}

    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ inputs.terraform_version }}
      - run: terraform init
      - run: terraform fmt -check
      - run: terraform validate
      - run: terraform plan -out=tfplan
      - run: terraform apply -auto-approve tfplan
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
```

### terraform-cloudflare.yml (caller)

```yaml
name: Terraform Cloudflare

on:
  push:
    branches: [main, master]
    paths: ['terraform/cloudflare/**']
  pull_request:
    branches: [main, master]
    paths: ['terraform/cloudflare/**']
  workflow_dispatch:

jobs:
  apply:
    uses: ./.github/workflows/terraform-apply.yml
    with:
      working_directory: terraform/cloudflare
    secrets: inherit
```

---

## Lessons Learned

1. **Zone ID vs Account ID** - Don't confuse them. Zone ID is specific to each domain.

2. **Cloudflare Provider v4 vs v5** - v5 is latest but has stability issues. Stick with v4.

3. **Import blocks** - Use Terraform 1.5+ `import {}` blocks instead of CLI `terraform import`. Removes after first apply.

4. **Tunnel secret** - When importing existing tunnel, use `lifecycle { ignore_changes = [secret] }` to avoid recreation.

5. **Tunnel name matters** - Must match existing tunnel name (`k8s-tunnel` not `smhomelab-tunnel`) or Terraform will recreate it.

6. **R2 bucket location** - Cannot be changed after creation. Match the actual location in config.

7. **Doppler GitHub Sync** - Use separate project `smhomelub-infra` for infrastructure secrets, separate from app secrets.

8. **Cache rules conflict** - If Dashboard has existing cache rules, either import them or delete from Dashboard first.

---

## Setup Guide

### Step 1: Create Cloudflare API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com) → My Profile → API Tokens
2. Create Token → Custom Token
3. Add permissions:

| Scope | Permission | Access |
|-------|------------|--------|
| Account | Workers R2 Storage | Edit |
| Account | Cloudflare Tunnel | Edit |
| Account | Account Rulesets | Edit |
| Zone | Zone | Edit |
| Zone | Cache Rules | Edit |

4. Zone Resources: Include → Specific zone → `gaynance.com`
5. Account Resources: Include → Specific account → your account
6. Create Token → Copy the token

### Step 2: Create R2 API Token

1. Go to Cloudflare Dashboard → R2 Object Storage → Manage R2 API Tokens
2. Create API Token
3. Permissions: Object Read & Write
4. Specify bucket: `terraform-state` (or All buckets)
5. Copy Access Key ID and Secret Access Key

### Step 3: Setup Doppler

1. Go to [Doppler Dashboard](https://dashboard.doppler.com)
2. Create project: `smhomelub-infra`
3. Create configs: `cicd` and `shared`
4. Add secrets to `cicd`:

| Secret | Value |
|--------|-------|
| `R2_ACCESS_KEY_ID` | From Step 2 |
| `R2_SECRET_ACCESS_KEY` | From Step 2 |
| `CLOUDFLARE_API_TOKEN` | From Step 1 |
| `DOPPLER_TOKEN` | Service Token with write access to `shared` |

### Step 4: Setup Doppler GitHub Sync

1. Doppler → Project `smhomelub-infra` → Config `cicd` → Integrations
2. Add Sync → GitHub Actions
3. Select repository: `smhomelab-infrastructure`
4. Sync → Secrets will appear in GitHub repo settings

### Step 5: Delete existing Cache Rules (if any)

1. Cloudflare Dashboard → gaynance.com → Caching → Cache Rules
2. Delete all existing rules (Terraform will recreate them)

### Step 6: Create Doppler Service Tokens

**For Terraform (write to shared):**
1. Doppler → `smhomelub-infra` → Config `shared` → Access tab
2. Generate → Service Token
3. ✅ Enable **Write access**
4. Name: `terraform-write`
5. Add to `cicd` config as `DOPPLER_TOKEN`

**For K8s ExternalSecrets (read from shared):**
1. Doppler → `smhomelub-infra` → Config `shared` → Access tab
2. Generate → Service Token (Read only)
3. Name: `k8s-externalsecrets`
4. Create K8s secret manually:
```bash
kubectl create secret generic doppler-token-infra-shared \
  --namespace external-secrets \
  --from-literal=dopplerToken="dp.st.shared.XXXX"
```

> **Why Service Tokens?** Least privilege - separate tokens for CI/CD and K8s.

---

## Migration: cloudflared to Token Mode

After Terraform successfully applies, `CF_TUNNEL_TOKEN` is automatically written to Doppler.

### How it works (fully automated)

```
┌─────────────────────────────────────────────────────────────┐
│                    TERRAFORM APPLY                           │
│                                                              │
│  1. Creates/updates Cloudflare tunnel                       │
│  2. Writes tunnel_token to Doppler via doppler_secret       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      DOPPLER                                 │
│  CF_TUNNEL_TOKEN ← автоматически от Terraform               │
│       │                                                      │
│       └─→ ExternalSecrets → K8s Secret                      │
└─────────────────────────────────────────────────────────────┘
```

No manual steps required!

### Step 3: Update cloudflared Helm values

Change from config-based to token-based:

```yaml
# Before (config mode)
cloudflared:
  args:
    - tunnel
    - --config
    - /etc/cloudflared/config.yaml
    - run

# After (token mode)
cloudflared:
  args:
    - tunnel
    - --no-autoupdate
    - run
    - --token
    - $(CF_TUNNEL_TOKEN)
  env:
    - name: CF_TUNNEL_TOKEN
      valueFrom:
        secretKeyRef:
          name: cloudflared-secrets
          key: CF_TUNNEL_TOKEN
```

### Step 4: Remove ConfigMap

Token mode doesn't need config.yaml ConfigMap - ingress rules come from Cloudflare API.

### Step 5: Verify

```bash
kubectl logs -n cloudflared deployment/cloudflared
# Should show: "Connection established" without config errors
```

---

## Cleanup

After successful migration:

### Remove import blocks

Edit `tunnel.tf` and `r2.tf` - remove all `import {}` blocks:

```hcl
# DELETE these blocks after first successful apply
import {
  to = cloudflare_zero_trust_tunnel_cloudflared.main
  id = "${var.cloudflare_account_id}/${var.existing_tunnel_id}"
}
```

### Remove existing_tunnel_id variable

After imports removed, `existing_tunnel_id` variable is no longer needed.

---

## Next Steps

1. ✅ Fix cache rules authentication error (added Account Rulesets Edit)
2. ✅ Automate tunnel_token → Doppler (via doppler_secret resource)
3. ✅ Update ArgoCD charts (cloudflared --token mode)
4. ✅ Remove import blocks (kept terraform-state for DR)
5. ✅ Migrate all ExternalSecrets to doppler-infra-shared
6. ✅ Update brain docs with final architecture

---

## Sources

- [Cloudflare: Deploy tunnels with Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [Terraform: cloudflare_zero_trust_tunnel_cloudflared](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared)
- [GitHub: Reusing workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [Doppler: GitHub Actions integration](https://docs.doppler.com/docs/github-actions)
