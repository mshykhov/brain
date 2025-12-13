# Documentation Structure Plan

Based on ArgoCD, Kubernetes docs best practices.

## Proposed Structure

```
docs/
├── README.md                      # Navigation index
│
├── getting-started/               # Quick start (5-10 min)
│   ├── prerequisites.md           # Requirements
│   ├── quick-start.md             # Minimal setup
│   └── first-deployment.md        # Deploy first service
│
├── setup/                         # Detailed setup guides
│   ├── cluster/
│   │   ├── k3s.md
│   │   └── eks.md
│   ├── argocd.md
│   ├── doppler.md
│   ├── auth0.md
│   ├── tailscale.md
│   ├── cloudflare-tunnel.md
│   └── external-dns.md
│
├── operations/                    # Day-2 operations
│   ├── adding-environment.md
│   ├── adding-service.md
│   ├── database-management.md
│   ├── backup-restore.md
│   └── scaling.md
│
├── troubleshooting/               # Problem solving
│   ├── argocd.md
│   ├── secrets.md
│   ├── networking.md
│   └── databases.md
│
├── reference/                     # Reference docs
│   ├── values-schema.md           # All values.yaml params
│   ├── secrets-reference.md       # All Doppler secrets
│   └── architecture.md            # Diagrams
│
└── concepts/                      # Optional - theory
    ├── gitops.md
    └── app-of-apps.md
```

## Key Principles

1. **Audience-based** - setup for admins, operations for DevOps
2. **Task-oriented** - "how to do X", not "what is X"
3. **Progressive disclosure** - simple to complex
4. **Searchable** - one file = one topic
5. **DRY** - reference common things, don't repeat

## Sources

- [ArgoCD docs](https://github.com/argoproj/argo-cd/tree/master/docs)
- [Kubernetes docs](https://kubernetes.io/docs/)
- [GitOps best practices - Google Cloud](https://cloud.google.com/kubernetes-engine/enterprise/config-sync/docs/concepts/gitops-best-practices)
- [DevOps Documentation Best Practices - MOSS](https://moss.sh/devops-monitoring/devops-documentation-best-practices/)

## Priority Order

1. setup/doppler.md - secrets are critical
2. setup/auth0.md - authentication
3. setup/tailscale.md - private access
4. setup/cloudflare-tunnel.md - public access
5. troubleshooting/* - common issues
6. reference/secrets-reference.md - all secrets in one place
