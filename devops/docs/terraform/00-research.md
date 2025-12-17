# Terraform Integration Research

## Decision

**Terraform for Cloudflare only.** Everything else stays manual.

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
│  │ R2 Buckets (cnpg-backups, terraform-state)  │    │
│  │ Cache Rules (sw.js bypass)                  │    │
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
│  - cloudflared deployment                           │
│  - tunnel ingress config (ConfigMap)                │
│  - DNS records (External-DNS)                       │
└─────────────────────────────────────────────────────┘
```

---

## What Terraform Manages

| Resource | Why |
|----------|-----|
| Zero Trust Tunnel | DR-critical, credentials backup |
| R2 Buckets | State storage, CNPG backups |
| Cache Rules | sw.js bypass for PWA updates |

## What Terraform Does NOT Manage

| Resource | Who Manages | Why |
|----------|-------------|-----|
| DNS records for services | External-DNS | Dynamic, change with deploys |
| Tunnel ingress rules | K8s ConfigMap | Part of app config |
| cloudflared deployment | ArgoCD Helm | K8s workload |
| Tunnel credentials | Doppler → ExternalSecret | Already working |
| Zone (gaynance.com) | Manual (done) | One-time setup |

---

## Repository Structure

```
infrastructure/
├── terraform/
│   ├── main.tf              # Provider + backend
│   ├── tunnel.tf            # Zero Trust Tunnel
│   ├── r2.tf                # R2 buckets
│   ├── cache_rules.tf       # Cache rules for sw.js
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Tunnel token output
│   └── versions.tf          # Version constraints
├── apps/                    # ArgoCD (unchanged)
├── charts/                  # Helm charts (unchanged)
└── ...
```

**No environment directories.** Cloudflare resources are global.

---

## GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `R2_ACCESS_KEY_ID` | R2 API access key |
| `R2_SECRET_ACCESS_KEY` | R2 API secret key |
| `CF_API_TOKEN` | Cloudflare API token |
| `CF_ACCOUNT_ID` | Cloudflare account ID |
| `CF_ZONE_ID` | Zone ID for gaynance.com |

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
