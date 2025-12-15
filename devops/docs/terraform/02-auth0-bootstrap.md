# Auth0 Bootstrap for Terraform

## The Chicken-Egg Problem

Terraform needs M2M app with Management API access to manage Auth0.
But we want Terraform to manage all Auth0 resources.

**Solution:** 2-stage bootstrap.

## Stage 1: Manual Bootstrap (one-time)

### Create M2M Application

In **Auth0 Dashboard** → **Applications** → **Create Application**:

| Field | Value |
|-------|-------|
| Name | `Terraform Bootstrap` |
| Type | Machine to Machine |

### Authorize Management API

**APIs** → **Auth0 Management API** → **Machine to Machine Applications**:

Select `Terraform Bootstrap` and grant permissions:

```
read:clients
create:clients
update:clients
delete:clients
read:client_grants
create:client_grants
update:client_grants
delete:client_grants
read:roles
create:roles
update:roles
delete:roles
read:actions
create:actions
update:actions
delete:actions
read:connections
create:connections
update:connections
delete:connections
```

### Save Credentials

Store in GitHub Secrets (for GitHub Actions):
- `AUTH0_DOMAIN` — your-tenant.auth0.com
- `AUTH0_CLIENT_ID` — from app settings
- `AUTH0_CLIENT_SECRET` — from app settings

Or in Vault for local development.

## Stage 2: Terraform Manages Everything Else

### Provider Configuration

```hcl
# providers.tf
terraform {
  required_providers {
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.0"
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_client_id
  client_secret = var.auth0_client_secret
}
```

### Variables

```hcl
# variables.tf
variable "auth0_domain" {
  type        = string
  description = "Auth0 tenant domain"
}

variable "auth0_client_id" {
  type        = string
  description = "Bootstrap M2M app client ID"
}

variable "auth0_client_secret" {
  type        = string
  sensitive   = true
  description = "Bootstrap M2M app client secret"
}
```

## What Terraform Manages

### Database Access Roles

```hcl
# modules/auth0-roles/main.tf
locals {
  access_levels = ["readonly", "readwrite", "admin"]
  environments  = ["dev", "prd"]
  apps          = var.database_apps  # ["blackpoint", "notifier"]
}

# db-{access} roles
resource "auth0_role" "db_access" {
  for_each    = toset(local.access_levels)
  name        = "db-${each.key}"
  description = "Database ${each.key} access level"
}

# db-app-{app} roles
resource "auth0_role" "db_app" {
  for_each    = toset(local.apps)
  name        = "db-app-${each.key}"
  description = "Access to ${each.key} database"
}

# db-env-{env} roles
resource "auth0_role" "db_env" {
  for_each    = toset(local.environments)
  name        = "db-env-${each.key}"
  description = "Access to ${each.key} environment"
}
```

### Vault Roles Action

```hcl
# modules/auth0-roles/action.tf
resource "auth0_action" "vault_roles" {
  name    = "Add Vault Roles"
  runtime = "node18"
  deploy  = true

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }

  code = file("${path.module}/actions/vault-roles.js")
}

resource "auth0_trigger_actions" "post_login" {
  trigger = "post-login"

  actions {
    id           = auth0_action.vault_roles.id
    display_name = auth0_action.vault_roles.name
  }
}
```

### OAuth2 Proxy Application

```hcl
# modules/auth0-app/main.tf
resource "auth0_client" "oauth2_proxy" {
  name        = "OAuth2 Proxy - ${var.environment}"
  app_type    = "regular_web"

  callbacks = [
    "https://argocd.${var.domain}/oauth2/callback",
    "https://grafana.${var.domain}/oauth2/callback",
    "https://vault.${var.tailnet}.ts.net/ui/vault/auth/oidc/oidc/callback"
  ]

  allowed_logout_urls = [
    "https://argocd.${var.domain}",
    "https://grafana.${var.domain}"
  ]

  oidc_conformant = true

  jwt_configuration {
    alg = "RS256"
  }
}

# Output for External Secrets
output "client_id" {
  value = auth0_client.oauth2_proxy.client_id
}

output "client_secret" {
  value     = auth0_client.oauth2_proxy.client_secret
  sensitive = true
}
```

## Integration with Vault

Write Auth0 secrets to Vault for External Secrets to read:

```hcl
# Write to Vault
resource "vault_kv_secret_v2" "oauth2_proxy" {
  mount = "secret"
  name  = "oauth2-proxy/auth0"

  data_json = jsonencode({
    client_id     = auth0_client.oauth2_proxy.client_id
    client_secret = auth0_client.oauth2_proxy.client_secret
  })
}
```

Then External Secrets in K8s reads from Vault.

## Adding New Database

With Terraform, adding new database roles:

```hcl
# environments/prd/main.tf
module "auth0_roles" {
  source = "../../modules/auth0-roles"

  database_apps = [
    "blackpoint",
    "notifier",
    "new-app"  # Just add here
  ]
}
```

Run `terraform apply` — roles created automatically.

## Sources

- [Auth0 Terraform Provider Quickstart](https://registry.terraform.io/providers/auth0/auth0/latest/docs/guides/quickstart)
- [Get Started with Auth0 Terraform Provider](https://auth0.com/blog/get-started-with-auth0-terraform-provider/)
- [auth0_role Resource](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/role)
- [auth0_action Resource](https://registry.terraform.io/providers/auth0/auth0/latest/docs/resources/action)
