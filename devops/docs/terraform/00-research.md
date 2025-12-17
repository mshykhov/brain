# Terraform Integration Research

## Overview

Terraform дополняет ArgoCD GitOps систему, управляя ресурсами **вне** Kubernetes кластера.

```
┌─────────────────────────────────────────────────────────────┐
│                      TERRAFORM                               │
│  Внешние ресурсы (вне K8s кластера)                         │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────┐  │
│  │Cloudflare │ │   Auth0   │ │  Doppler  │ │  Tailscale  │  │
│  │- Tunnel   │ │- Apps     │ │- Projects │ │- ACLs       │  │
│  │- DNS      │ │- Actions  │ │- Secrets  │ │- OAuth keys │  │
│  │- R2       │ │- APIs     │ │- Tokens   │ │             │  │
│  └───────────┘ └───────────┘ └───────────┘ └─────────────┘  │
│                         │                                    │
│              Outputs → Vault/Doppler Secrets                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (External Secrets sync)
┌─────────────────────────────────────────────────────────────┐
│                    ARGOCD (без изменений)                    │
│  K8s workloads                                               │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌─────────────┐  │
│  │App-of-Apps│ │  Services │ │ Databases │ │Image Updater│  │
│  │- Helm     │ │- deploy   │ │- CNPG     │ │- auto update│  │
│  │- manifests│ │- configs  │ │- Redis    │ │- notify     │  │
│  └───────────┘ └───────────┘ └───────────┘ └─────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Why Add Terraform

| Problem Now | Terraform Solution |
|-------------|-------------------|
| Cloudflare tunnel created via CLI manually | IaC, versioning, reproducibility |
| Auth0 apps/actions configured in UI | Code in Git, review, history |
| Doppler projects created manually | Automation, consistent environments |
| README documentation with placeholders | Configuration as code |
| Disaster recovery requires manual steps | `terraform apply` restores everything |

## What Terraform Manages

### Cloudflare ([provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs))

```hcl
resource "cloudflare_tunnel" "main" {
  account_id = var.cloudflare_account_id
  name       = "smhomelab-tunnel"
  secret     = random_password.tunnel_secret.result
}

resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  value   = "${cloudflare_tunnel.main.id}.cfargotunnel.com"
  proxied = true
}

resource "cloudflare_r2_bucket" "cnpg_backups" {
  account_id = var.cloudflare_account_id
  name       = "cnpg-backups"
  location   = "WEUR"
}
```

**Currently manual:** Tunnel ID, credentials.json, DNS records, R2 buckets

### Auth0 ([provider](https://registry.terraform.io/providers/auth0/auth0/latest/docs))

```hcl
resource "auth0_client" "oauth2_proxy" {
  name        = "oauth2-proxy"
  app_type    = "regular_web"
  callbacks   = ["https://oauth.${var.domain}/oauth2/callback"]

  jwt_configuration {
    alg = "RS256"
  }
}

resource "auth0_action" "add_groups" {
  name    = "Add Groups to Token"
  runtime = "node18"
  deploy  = true

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  code = file("${path.module}/actions/add-groups.js")
}
```

**Currently manual:** Applications, Actions, callback URLs

### Doppler ([provider](https://registry.terraform.io/providers/DopplerHQ/doppler/latest/docs))

```hcl
resource "doppler_project" "smhomelab" {
  name = "smhomelab"
}

resource "doppler_environment" "envs" {
  for_each = toset(["dev", "prd", "shared"])
  project  = doppler_project.smhomelab.name
  slug     = each.key
}

# Sync secrets from Terraform outputs
resource "doppler_secret" "cf_tunnel_credentials" {
  project = doppler_project.smhomelab.name
  config  = "shared"
  name    = "CF_TUNNEL_CREDENTIALS"
  value   = jsonencode(cloudflare_tunnel.main.tunnel_token)
}
```

### Tailscale ([provider](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs))

```hcl
resource "tailscale_tailnet_key" "k8s_operator" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  tags          = ["tag:k8s"]
}

resource "tailscale_acl" "policy" {
  acl = jsonencode({
    tagOwners = {
      "tag:k8s" = ["autogroup:admin"]
    }
  })
}
```

## Pros and Cons

### Pros

| Advantage | Description |
|-----------|-------------|
| **IaC for external services** | Cloudflare, Auth0, Doppler — all in Git |
| **Disaster Recovery** | Restore entire infrastructure with one command |
| **Reproducibility** | New environment = `terraform apply -var-file=new.tfvars` |
| **Audit trail** | Change history in Git |
| **No manual steps** | README placeholders → automatic setup |
| **Secrets flow** | TF outputs → Vault/Doppler → External Secrets → K8s |

### Cons / Challenges

| Challenge | Solution |
|-----------|----------|
| State storage | Use Cloudflare R2 (already have) |
| Secrets for TF | GitHub Secrets or Doppler CLI |
| Learning curve | Start with Cloudflare (simple provider) |
| Drift from UI edits | Don't edit manually after migration |

## Alternative: Tofu-Controller (GitOps for Terraform)

If you want GitOps for Terraform inside the cluster:

```yaml
apiVersion: infra.contrib.fluxcd.io/v1alpha2
kind: Terraform
metadata:
  name: external-infrastructure
  namespace: flux-system
spec:
  path: ./terraform
  sourceRef:
    kind: GitRepository
    name: infrastructure
  interval: 1h
  approvePlan: auto
```

**Pros:**
- GitOps workflow for Terraform
- Automatic drift detection and remediation
- State stored in Kubernetes Secret

**Cons:**
- Additional complexity (Flux + Tofu-Controller)
- Weaveworks shut down, future uncertain (project moved to community)

## Why NOT Full Migration from ArgoCD

| Feature | ArgoCD | Terraform |
|---------|--------|-----------|
| Continuous reconciliation | Yes (pull-based) | No (push-based) |
| Self-healing | Yes | No |
| Drift detection | Real-time | On-demand |
| Image auto-update | ArgoCD Image Updater | No equivalent |
| Rollbacks | Built-in | Revert + apply |
| UI for K8s | Yes | No |

**Verdict:** Keep ArgoCD for K8s workloads, add Terraform for external resources.

## Implementation Priority

1. **Cloudflare** — highest value (tunnel, DNS, R2)
2. **Auth0** — applications, actions, roles
3. **Doppler** — optional (already works fine manually)
4. **Tailscale** — ACLs, OAuth clients

## Sources

- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://developer.hashicorp.com/terraform/tutorials/kubernetes/helm-provider)
- [ArgoCD Terraform Provider](https://github.com/argoproj-labs/terraform-provider-argocd)
- [Tofu Controller](https://flux-iac.github.io/tofu-controller/)
- [Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Auth0 Provider](https://registry.terraform.io/providers/auth0/auth0/latest/docs)
- [Doppler Provider](https://registry.terraform.io/providers/DopplerHQ/doppler/latest/docs)
- [Tailscale Provider](https://registry.terraform.io/providers/tailscale/tailscale/latest/docs)
- [Terraform vs Helm Comparison](https://spacelift.io/blog/helm-vs-terraform)
- [ArgoCD with Terraform Integration](https://akuity.io/blog/yet-another-take-on-integrating-terraform-with-argo-cd)
- [GitOps Tools Comparison 2025](https://spacelift.io/blog/gitops-tools)
