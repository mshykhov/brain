# Cloudflare R2 Setup

## Create Bucket

1. Cloudflare Dashboard → R2 → Create bucket
2. Name: `velero-backups`
3. Location: Auto (or specific region)

## Create API Token

1. R2 → Manage R2 API Tokens → Create API token
2. Token name: `velero-backup`
3. Permissions: **Object Read & Write**
4. Specify bucket: `velero-backups`
5. TTL: No expiration (or set rotation schedule)

Save credentials:
- Access Key ID
- Secret Access Key
- Account ID (for endpoint URL)

## R2 Endpoint

```
https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

Find Account ID: Cloudflare Dashboard → R2 → bucket → Settings

## Add to Doppler

```bash
# In Doppler (shared config)
S3_ACCESS_KEY_ID=<access-key>
S3_SECRET_ACCESS_KEY=<secret-key>
```

## Update Infrastructure

Edit `apps/values.yaml`:

```yaml
global:
  s3:
    endpoint: https://<ACCOUNT_ID>.r2.cloudflarestorage.com
    bucket: velero-backups
    region: auto
```

## Pricing

| Resource | Free Tier | Paid |
|----------|-----------|------|
| Storage | 10 GB/month | $0.015/GB |
| Class A ops | 1M/month | $4.50/M |
| Class B ops | 10M/month | $0.36/M |
| Egress | **Unlimited** | **$0** |

## Verification

```bash
# Test with AWS CLI
aws s3 ls s3://velero-backups \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```
