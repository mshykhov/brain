# Terraform Integration Research

## Decision

**Terraform for Cloudflare + Doppler integration.**

| Provider | Decision | Reason |
|----------|----------|--------|
| Cloudflare | **Yes** | DR-critical, highest ROI |
| Doppler | **Yes** | Terraform writes secrets (CF_TUNNEL_TOKEN) |
| Auth0 | No | 3-4 apps, rarely change |
| Tailscale | No | ACLs change yearly |

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    TERRAFORM                         │
│  Cloudflare + Doppler providers                     │
│  ┌─────────────────────────────────────────────┐    │
│  │ Zero Trust Tunnel (DR-critical)             │    │
│  │ R2 Buckets (cnpg-backups, terraform-state)  │    │
│  │ Cache Rules (sw.js bypass)                  │    │
│  │ Tunnel Config (remotely-managed ingress)    │    │
│  └─────────────────────────────────────────────┘    │
│                      │                               │
│               doppler_secret                         │
│                      ▼                               │
│      Doppler (smhomelub-infra/shared)               │
│         CF_TUNNEL_TOKEN (auto)                       │
└─────────────────────────────────────────────────────┘
                       │
                       ▼ ExternalSecrets
┌─────────────────────────────────────────────────────┐
│                    ARGOCD                            │
│  K8s workloads                                      │
│  - cloudflared (token mode, no ConfigMap)           │
│  - DNS records (External-DNS)                       │
└─────────────────────────────────────────────────────┘
```

---

## What Terraform Manages

| Resource | Why |
|----------|-----|
| Zero Trust Tunnel | DR-critical, credentials backup |
| Tunnel Config (ingress) | Remotely-managed, no K8s ConfigMap |
| R2 Buckets | State storage, CNPG backups |
| Cache Rules | sw.js bypass for PWA updates |
| Doppler secrets | Auto-write CF_TUNNEL_TOKEN |

## What Terraform Does NOT Manage

| Resource | Who Manages | Why |
|----------|-------------|-----|
| DNS records for services | External-DNS | Dynamic, change with deploys |
| cloudflared deployment | ArgoCD Helm | K8s workload |
| Zone (gaynance.com) | Manual (done) | One-time setup |

---

## Repository Structure

```
infrastructure/
├── .github/workflows/
│   ├── terraform-apply.yml      # Reusable workflow
│   └── terraform-cloudflare.yml # Caller
├── terraform/cloudflare/
│   ├── versions.tf              # Terraform + providers + R2 backend
│   ├── providers.tf             # Cloudflare + Doppler providers
│   ├── variables.tf             # Input variables
│   ├── terraform.tfvars         # Non-sensitive values
│   ├── tunnel.tf                # Tunnel + doppler_secret
│   ├── r2.tf                    # R2 buckets
│   └── cache.tf                 # Cache rules
├── apps/                        # ArgoCD (unchanged)
├── charts/                      # Helm charts (unchanged)
└── ...
```

**No environment directories.** Cloudflare resources are global.

---

## GitHub Secrets (via Doppler Sync)

Secrets synced from `smhomelub-infra/cicd`:

| Secret | Description |
|--------|-------------|
| `R2_ACCESS_KEY_ID` | R2 API access key |
| `R2_SECRET_ACCESS_KEY` | R2 API secret key |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token |
| `DOPPLER_TOKEN` | Service Token (write to shared) |

---

## Workflow

```
1. Developer edits terraform/*.tf
2. git push (creates PR)
3. GitHub Actions: terraform plan
4. Plan appears as PR comment
5. Code review → Merge
6. GitHub Actions: terraform apply
7. Cloudflare updated automatically
```

---

## Future Expansion (Only If Needed)

| Provider | When to Add |
|----------|-------------|
| Auth0 | If apps > 5 or frequent changes |
| Terraform Cloud | If team > 2 (for state locking UI) |

---

## Sources

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Cloudflare Tunnel Terraform Guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deploy-tunnels/deployment-guides/terraform/)
- [Terraform S3 Backend](https://developer.hashicorp.com/terraform/language/settings/backends/s3)
- [GitHub Actions for Terraform](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [cf-terraforming Tool](https://github.com/cloudflare/cf-terraforming)
