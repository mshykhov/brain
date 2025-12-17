# Cloudflare Migration to Terraform (Option B - Remotely Managed)

Full tunnel control via Terraform + GitHub Actions CI/CD.

## Current Status

| Resource | Status | Notes |
|----------|--------|-------|
| Tunnel | ✅ Imported | `k8s-tunnel` |
| Tunnel Config | ✅ Created | Remotely-managed ingress |
| R2 buckets | ✅ Imported | cnpg-backups (APAC), terraform-state (WEUR) |
| Cache Rules | ❌ Blocked | Authentication error - investigating |

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
│  Project: smhomelub-infra / prd                             │
│  Secrets:                                                    │
│    - R2_ACCESS_KEY_ID                                       │
│    - R2_SECRET_ACCESS_KEY                                   │
│    - CLOUDFLARE_API_TOKEN                                   │
│  Sync: GitHub Actions → smhomelab-infrastructure            │
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
| Zone | Zone | Edit |
| Zone | Cache Rules | Edit |

**Zone Resources:** gaynance.com only
**Account Resources:** Smhomelub@gmail.com's Account

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
# Import existing tunnel (Terraform 1.5+ import block)
# Remove this block after first successful apply
import {
  to = cloudflare_zero_trust_tunnel_cloudflared.main
  id = "${var.cloudflare_account_id}/${var.existing_tunnel_id}"
}

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
```

### r2.tf

```hcl
import {
  to = cloudflare_r2_bucket.cnpg_backups
  id = "${var.cloudflare_account_id}/cnpg-backups"
}

import {
  to = cloudflare_r2_bucket.terraform_state
  id = "${var.cloudflare_account_id}/terraform-state"
}

resource "cloudflare_r2_bucket" "cnpg_backups" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "APAC"
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

---

## Next Steps

1. ❌ Fix cache rules authentication error
2. Get tunnel_token output after successful apply
3. Update Doppler with CF_TUNNEL_TOKEN
4. Update ArgoCD charts (cloudflared --token)
5. Remove import blocks after first successful apply

---

## Sources

- [Cloudflare: Deploy tunnels with Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [Terraform: cloudflare_zero_trust_tunnel_cloudflared](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zero_trust_tunnel_cloudflared)
- [GitHub: Reusing workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [Doppler: GitHub Actions integration](https://docs.doppler.com/docs/github-actions)
