# Phase 11: Backup & Disaster Recovery

## Overview

Production-grade backup solution using Velero with Cloudflare R2 storage.

## Components

| Component | Purpose |
|-----------|---------|
| Velero | Kubernetes backup/restore |
| Cloudflare R2 | S3-compatible object storage |
| CSI Snapshots | Volume-level backups |

## Architecture

```
Velero Server → S3 API → Cloudflare R2
     ↓
Node Agent (file-level backup)
     ↓
CSI Driver (volume snapshots)
```

## Why Velero + R2?

1. **Velero** - CNCF standard for K8s backup
2. **R2** - Zero egress fees, 10GB free tier
3. **GitOps** - Full configuration in git

## Documents

1. [Cloudflare R2 Setup](./01-cloudflare-r2.md)
2. [Velero Installation](./02-velero-install.md)
3. [Backup Schedules](./03-schedules.md)
4. [Restore Procedures](./04-restore.md)
5. [Monitoring & Alerts](./05-monitoring.md)
