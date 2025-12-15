# Terraform Setup Guide

## Overview

Terraform manages resources **outside** Kubernetes cluster:
- Auth0 (apps, roles, actions)
- Cloudflare (DNS, tunnels)
- Vault secrets (written by TF, read by External Secrets)

ArgoCD/Helm manages resources **inside** cluster.

## Repository Structure

```
infrastructure/
├── terraform/
│   ├── modules/                    # Reusable modules
│   │   ├── auth0-roles/
│   │   ├── auth0-app/
│   │   └── vault-secret/
│   └── environments/
│       ├── shared/                 # Tenant-wide config
│       │   ├── backend.tf
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── terraform.tfvars
│       ├── dev/
│       │   └── ...
│       └── prd/
│           └── ...
├── charts/                         # Helm charts
├── apps/                           # ArgoCD apps
└── manifests/                      # K8s manifests
```

## Where to Run

**GitHub Actions** — recommended for small teams:

| Option | Verdict |
|--------|---------|
| GitHub Actions | ✅ Free, PR preview, already have GitHub |
| Terraform Cloud | ⚠️ 500 resource limit, 1 concurrent run |
| Atlantis | ❌ Overkill for solo/small team |
| tf-controller | ❌ Requires Flux (we use ArgoCD) |
| Local | ❌ No audit trail, no automation |

## State Management

**Cloudflare R2** (S3-compatible):
- Free up to 10GB
- No egress fees
- Already used for CNPG backups

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "prd/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://<CF_ACCOUNT_ID>.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}
```

## Environment Separation

**Use directories, NOT workspaces** for dev/prd:

```
environments/
├── dev/
│   ├── backend.tf      # key = "dev/terraform.tfstate"
│   └── main.tf
└── prd/
    ├── backend.tf      # key = "prd/terraform.tfstate"
    └── main.tf
```

Why not workspaces:
- Shared backend = shared credentials
- Easy to apply to wrong environment
- No blast radius isolation

## GitHub Actions Workflow

```yaml
# .github/workflows/terraform.yml
name: Terraform

on:
  pull_request:
    paths:
      - 'terraform/**'
  push:
    branches: [master]
    paths:
      - 'terraform/**'

permissions:
  contents: read
  pull-requests: write

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform/environments/${{ matrix.env }}
    strategy:
      matrix:
        env: [dev, prd]

    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0

      - name: Terraform Init
        run: terraform init
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_ACCESS_KEY }}

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        env:
          TF_VAR_auth0_client_secret: ${{ secrets.AUTH0_CLIENT_SECRET }}

      - name: Comment PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `#### Terraform Plan (${{ matrix.env }})\n\`\`\`\n${{ steps.plan.outputs.stdout }}\n\`\`\``
            })

      - name: Terraform Apply
        if: github.ref == 'refs/heads/master' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan
```

## Workflow

```
1. Create PR
   └─> GitHub Actions: terraform plan
       └─> Comment plan in PR

2. Merge to master
   └─> GitHub Actions: terraform apply
       ├─> Create Auth0 resources
       ├─> Write secrets to Vault
       └─> Update Cloudflare DNS

3. ArgoCD sync
   └─> External Secrets read from Vault
       └─> Create K8s Secrets
```

## Sources

- [Terraform Monorepo vs Multi-repo](https://www.hashicorp.com/en/blog/terraform-mono-repo-vs-multi-repo-the-great-debate)
- [Standard Module Structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Best practices for code structure - Google Cloud](https://cloud.google.com/docs/terraform/best-practices/general-style-structure)
