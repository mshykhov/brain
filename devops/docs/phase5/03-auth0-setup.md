# Auth0 Setup for oauth2-proxy

## 1. Create Auth0 Tenant

1. Go to [auth0.com](https://auth0.com) → Sign Up
2. Create tenant (e.g., `example-dev`)
3. Note your domain: `example-dev.auth0.com`

## 2. Create Application

1. Auth0 Dashboard → Applications → Create Application
2. Name: `oauth2-proxy`
3. Type: **Regular Web Application**
4. Click Create

## 3. Configure Application Settings

### Basic Information
- **Name**: oauth2-proxy
- **Domain**: (auto-filled)

### Application URIs

**Allowed Callback URLs:**
```
https://argocd.internal.<tailnet>.ts.net/oauth2/callback,
https://longhorn.internal.<tailnet>.ts.net/oauth2/callback
```

> Replace `<tailnet>` with your actual tailnet name (e.g., `tailnet-abc123`)

**Allowed Logout URLs:**
```
https://argocd.internal.<tailnet>.ts.net,
https://longhorn.internal.<tailnet>.ts.net
```

**Allowed Web Origins:**
```
https://argocd.internal.<tailnet>.ts.net,
https://longhorn.internal.<tailnet>.ts.net
```

### Wildcard Option (Not Recommended for Production)

Auth0 supports wildcards for subdomains:
```
https://*.internal.<tailnet>.ts.net/oauth2/callback
```

But Auth0 warns: "Avoid using wildcard placeholders in production as it can make your application vulnerable."

## 4. Get Credentials

From Application Settings page:
- **Domain** → `AUTH0_DOMAIN` (e.g., `example-dev.auth0.com`)
- **Client ID** → `AUTH0_CLIENT_ID_OAUTH2_PROXY`
- **Client Secret** → `AUTH0_CLIENT_SECRET_OAUTH2_PROXY`

## 5. Generate Cookie Secret

```bash
openssl rand -base64 32 | head -c 32
```

This becomes `OAUTH2_PROXY_COOKIE_SECRET`

## 6. Add to Doppler

Project: `example` → Config: `shared`

| Key | Value |
|-----|-------|
| `AUTH0_DOMAIN` | `example-dev.auth0.com` |
| `AUTH0_CLIENT_ID_OAUTH2_PROXY` | (from Auth0) |
| `AUTH0_CLIENT_SECRET_OAUTH2_PROXY` | (from Auth0) |
| `OAUTH2_PROXY_COOKIE_SECRET` | (generated) |

## 7. Find Your Tailnet Name

After Tailscale Operator deploys, check the service:

```bash
kubectl get svc -n ingress-nginx nginx-tailscale
```

The external IP will show: `internal.tailnet-abc123.ts.net`

Or check Tailscale Admin Console → Machines

## 8. Update Ingress Hosts

Edit files in `manifests/network/ingresses/`:
- Replace `tailnet-xxxx` with your actual tailnet name

## Optional: User Management

### Restrict Access by Email Domain

In oauth2-proxy helm values, change:
```yaml
config:
  configFile: |-
    email_domains = [ "yourcompany.com" ]
```

### Add Users

Auth0 Dashboard → User Management → Users → Create User

## Troubleshooting

### Check oauth2-proxy logs
```bash
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy
```

### Common Issues

1. **Callback URL mismatch**: Ensure Auth0 callback URLs exactly match ingress hosts
2. **Cookie issues**: Try clearing browser cookies
3. **OIDC discovery failed**: Check AUTH0_DOMAIN is correct (no `https://` prefix)
