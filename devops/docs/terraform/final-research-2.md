# Terraform Integration: Final Plan

Based on analysis of existing docs, official best practices, and ROI considerations.

## Decision

**Implement Terraform for Cloudflare only.** Everything else stays manual.

| Provider | Decision | Reason |
|----------|----------|--------|
| Cloudflare | **Yes** | DR-critical, highest ROI |
| Auth0 | No | 3-4 apps, rarely change |
| Doppler | No | Created once, never touched |
| Tailscale | No | ACLs change yearly |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    TERRAFORM                         │
│  Cloudflare resources only                          │
│  ┌─────────────────────────────────────────────┐    │
│  │ Zero Trust Tunnel (DR-critical)             │    │
│  │ DNS Records (wildcard CNAME)                │    │
│  │ R2 Buckets (cnpg-backups, terraform-state)  │    │
│  └─────────────────────────────────────────────┘    │
│                      │                               │
│               terraform output                       │
│                      ▼                               │
│           tunnel_token (sensitive)                   │
│                      │                               │
│              Manual paste (once)                     │
│                      ▼                               │
│                   Doppler                            │
└─────────────────────────────────────────────────────┘
                       │
                       ▼ External Secrets
┌─────────────────────────────────────────────────────┐
│                    ARGOCD                            │
│  K8s workloads (unchanged)                          │
└─────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
infrastructure/
├── terraform/
│   ├── main.tf              # Provider + backend
│   ├── tunnel.tf            # Zero Trust Tunnel
│   ├── dns.tf               # DNS records
│   ├── r2.tf                # R2 buckets
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Tunnel token output
│   └── versions.tf          # Version constraints
├── apps/                    # ArgoCD (unchanged)
├── charts/                  # Helm charts (unchanged)
└── ...
```

**No environment directories.** Cloudflare resources are global.

---

## Implementation

### versions.tf

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
```

### variables.tf

```hcl
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with Zone:DNS:Edit, Tunnel:Edit, R2:Edit"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for gaynance.com"
}

variable "domain" {
  type        = string
  default     = "gaynance.com"
  description = "Primary domain"
}

variable "project" {
  type        = string
  default     = "smhomelab"
  description = "Project name prefix"
}
```

### tunnel.tf

```hcl
resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = var.cloudflare_account_id
  name       = "${var.project}-tunnel"
  secret     = base64encode(random_password.tunnel_secret.result)
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id

  config {
    ingress_rule {
      hostname = "*.${var.domain}"
      service  = "http://nginx-ingress-controller.ingress-nginx.svc.cluster.local:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
}
```

### dns.tf

```hcl
resource "cloudflare_record" "tunnel_wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "tunnel_root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
```

### r2.tf

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

### outputs.tf

```hcl
output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.id
  description = "Tunnel ID for reference"
}

output "tunnel_token" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.tunnel_token
  sensitive   = true
  description = "Tunnel token - paste to Doppler CF_TUNNEL_TOKEN"
}

output "tunnel_cname" {
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  description = "Tunnel CNAME target"
}
```

---

## GitHub Actions

### .github/workflows/terraform.yml

```yaml
name: Terraform

on:
  push:
    branches: [master]
    paths: ['infrastructure/terraform/**']
  pull_request:
    paths: ['infrastructure/terraform/**']

concurrency:
  group: terraform
  cancel-in-progress: false

permissions:
  contents: read
  pull-requests: write

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: infrastructure/terraform

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Format Check
        run: terraform fmt -check -recursive

      - name: Init
        run: terraform init
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}

      - name: Validate
        run: terraform validate

      - name: Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        env:
          TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
          TF_VAR_cloudflare_account_id: ${{ secrets.CF_ACCOUNT_ID }}
          TF_VAR_cloudflare_zone_id: ${{ secrets.CF_ZONE_ID }}

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `#### Terraform Plan
            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`
            `;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Apply
        if: github.ref == 'refs/heads/master' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
        env:
          TF_VAR_cloudflare_api_token: ${{ secrets.CF_API_TOKEN }}
          TF_VAR_cloudflare_account_id: ${{ secrets.CF_ACCOUNT_ID }}
          TF_VAR_cloudflare_zone_id: ${{ secrets.CF_ZONE_ID }}
```

---

## GitHub Secrets Required

| Secret | Description | Where to get |
|--------|-------------|--------------|
| `R2_ACCESS_KEY_ID` | R2 API access key | Cloudflare Dashboard → R2 → Manage API Tokens |
| `R2_SECRET_ACCESS_KEY` | R2 API secret key | Same as above |
| `CF_API_TOKEN` | Cloudflare API token | Cloudflare Dashboard → Profile → API Tokens |
| `CF_ACCOUNT_ID` | Cloudflare account ID | Cloudflare Dashboard → any zone → Overview (right sidebar) |
| `CF_ZONE_ID` | Zone ID for gaynance.com | Cloudflare Dashboard → gaynance.com → Overview (right sidebar) |

### Cloudflare API Token Permissions

Create custom token with:
- Zone → DNS → Edit
- Account → Cloudflare Tunnel → Edit
- Account → R2 Storage → Edit

---

## Bootstrap Steps

### 1. Create R2 bucket for state (manual, one-time)

```bash
# Via Cloudflare Dashboard or wrangler CLI
wrangler r2 bucket create terraform-state
```

### 2. Create R2 API credentials

Cloudflare Dashboard → R2 → Manage R2 API Tokens → Create API Token

### 3. Create Cloudflare API token

Cloudflare Dashboard → Profile → API Tokens → Create Token → Custom Token

Permissions:
- Zone:DNS:Edit (zone: gaynance.com)
- Account:Cloudflare Tunnel:Edit
- Account:R2 Storage:Edit

### 4. Add GitHub Secrets

Repository → Settings → Secrets and variables → Actions → New repository secret

### 5. Import existing resources

```bash
cd infrastructure/terraform
terraform init

# Import existing tunnel
terraform import cloudflare_zero_trust_tunnel_cloudflared.main \
  <account_id>/<tunnel_id>

# Import existing DNS records
terraform import cloudflare_record.tunnel_wildcard \
  <zone_id>/<record_id>

# Import existing R2 bucket
terraform import cloudflare_r2_bucket.cnpg_backups \
  <account_id>/cnpg-backups
```

### 6. Run terraform plan

```bash
terraform plan
```

Review changes, ensure no destructive actions.

### 7. Commit and push

```bash
git add infrastructure/terraform/
git commit -m "feat: add terraform for cloudflare resources"
git push
```

### 8. After apply - update Doppler

Get tunnel token:
```bash
terraform output -raw tunnel_token
```

Paste to Doppler → smhomelab → shared → `CF_TUNNEL_TOKEN`

---

## Disaster Recovery

### If tunnel is deleted

```bash
cd infrastructure/terraform

# Remove from state
terraform state rm cloudflare_zero_trust_tunnel_cloudflared.main

# Apply creates new tunnel
terraform apply

# Get new token
terraform output -raw tunnel_token

# Update Doppler with new token
# Restart cloudflared pods in K8s
kubectl rollout restart deployment cloudflared -n cloudflare
```

### If DNS is misconfigured

```bash
terraform apply
# Automatically fixes DNS to match config
```

### Full disaster recovery

```bash
# Clone repo
git clone git@github.com:mshykhov/smhomelab-infrastructure.git
cd smhomelab-infrastructure/infrastructure/terraform

# Set credentials
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export TF_VAR_cloudflare_api_token=...
export TF_VAR_cloudflare_account_id=...
export TF_VAR_cloudflare_zone_id=...

# Init and apply
terraform init
terraform apply

# Get tunnel token, update Doppler
terraform output -raw tunnel_token
```

---

## What NOT to Terraform

| Resource | Reason |
|----------|--------|
| Auth0 applications | 3-4 apps, stable, UI is fine |
| Auth0 actions | Rarely change |
| Doppler projects | Created once |
| Tailscale ACLs | Change yearly |
| Vault config | Managed by ArgoCD |
| K8s resources | Managed by ArgoCD |

---

## Future Expansion (Only If Needed)

### Add Auth0 (if apps > 5 or frequent changes)

```
terraform/
├── cloudflare/          # Current
└── auth0/               # New directory
    ├── main.tf
    ├── clients.tf
    └── actions.tf
```

Separate state file, separate workflow.

### Add Terraform Cloud (if team > 2)

Replace R2 backend with TF Cloud for:
- State locking (concurrent runs)
- Run history UI
- Cost estimation

---

## Sources

- [Cloudflare Zero Trust Tunnel Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [Cloudflare Provider Docs](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [GitHub Actions for Terraform](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Cloudflare R2 Terraform](https://developers.cloudflare.com/r2/examples/terraform/)
