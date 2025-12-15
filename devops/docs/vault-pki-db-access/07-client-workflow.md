# Developer Workflow

## 1. Prerequisites

### Install Vault CLI

```bash
# macOS
brew install hashicorp/tap/vault

# Windows (scoop)
scoop install vault

# Linux
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

### Configure Vault Address

```bash
# Add to ~/.bashrc or ~/.zshrc
export VAULT_ADDR="https://vault.trout-paradise.ts.net"
```

## 2. Login via Auth0

```bash
# Opens browser for Auth0 SSO
vault login -method=oidc

# Success output:
# Success! You are now authenticated.
# token          hvs.xxx
# token_accessor xxx
# token_policies ["default" "pki-readonly" "pki-app-blackpoint" "pki-env-dev"]
```

## 3. Get Certificate

### One-liner

```bash
vault write -format=json pki_int/issue/db-readonly \
    common_name="$(whoami)@company.com" \
    ttl="8760h" | tee cert.json | jq -r '
      .data.certificate, .data.private_key, .data.ca_chain[0]
    ' | awk 'NR==1{print > "client.crt"} NR==2{print > "client.key"} NR==3{print > "ca.crt"}'
```

### Step by Step

```bash
# Request certificate
vault write -format=json pki_int/issue/db-readonly \
    common_name="myron@company.com" \
    ttl="8760h" > cert.json

# Extract files
jq -r '.data.certificate' cert.json > ~/.pg/client.crt
jq -r '.data.private_key' cert.json > ~/.pg/client.key
jq -r '.data.ca_chain[0]' cert.json > ~/.pg/ca.crt

# Set permissions
chmod 600 ~/.pg/client.key
```

## 4. Connect to Database

### psql

```bash
psql "host=blackpoint-api-dev.trout-paradise.ts.net \
      port=5432 \
      dbname=blackpoint \
      user=readonly_user \
      sslmode=verify-full \
      sslcert=$HOME/.pg/client.crt \
      sslkey=$HOME/.pg/client.key \
      sslrootcert=$HOME/.pg/ca.crt"
```

### IntelliJ IDEA / DataGrip

1. **Database** → **+** → **Data Source** → **PostgreSQL**
2. Configure:
   ```
   Host: blackpoint-api-dev.trout-paradise.ts.net
   Port: 5432
   Database: blackpoint
   User: readonly_user
   ```
3. **SSH/SSL** tab:
   - ✅ Use SSL
   - **CA file**: `~/.pg/ca.crt`
   - **Client certificate file**: `~/.pg/client.crt`
   - **Client key file**: `~/.pg/client.key`
4. **Test Connection** → OK

## 5. Shell Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Vault shortcuts
alias vlogin='vault login -method=oidc'

# Get DB certificate (readonly)
vdb-cert-ro() {
    vault write -format=json pki_int/issue/db-readonly \
        common_name="$(whoami)@company.com" \
        ttl="${1:-8760h}" > ~/.pg/cert.json
    jq -r '.data.certificate' ~/.pg/cert.json > ~/.pg/client.crt
    jq -r '.data.private_key' ~/.pg/cert.json > ~/.pg/client.key
    jq -r '.data.ca_chain[0]' ~/.pg/cert.json > ~/.pg/ca.crt
    chmod 600 ~/.pg/client.key
    echo "Certificate saved to ~/.pg/"
    echo "Valid until: $(jq -r '.data.expiration | tonumber | strftime("%Y-%m-%d")' ~/.pg/cert.json)"
}

# Get DB certificate (readwrite)
vdb-cert-rw() {
    vault write -format=json pki_int/issue/db-readwrite \
        common_name="$(whoami)@company.com" \
        ttl="${1:-8760h}" > ~/.pg/cert.json
    jq -r '.data.certificate' ~/.pg/cert.json > ~/.pg/client.crt
    jq -r '.data.private_key' ~/.pg/cert.json > ~/.pg/client.key
    jq -r '.data.ca_chain[0]' ~/.pg/cert.json > ~/.pg/ca.crt
    chmod 600 ~/.pg/client.key
    echo "Certificate saved to ~/.pg/"
}

# Quick connect to databases
alias db-blackpoint-dev='psql "host=blackpoint-api-dev.trout-paradise.ts.net port=5432 dbname=blackpoint user=readonly_user sslmode=verify-full sslcert=$HOME/.pg/client.crt sslkey=$HOME/.pg/client.key sslrootcert=$HOME/.pg/ca.crt"'

alias db-blackpoint-prd='psql "host=blackpoint-api-prd.trout-paradise.ts.net port=5432 dbname=blackpoint user=readonly_user sslmode=verify-full sslcert=$HOME/.pg/client.crt sslkey=$HOME/.pg/client.key sslrootcert=$HOME/.pg/ca.crt"'
```

## 6. Daily Workflow

```bash
# Morning: login (once per 7 days)
vlogin

# Get/refresh certificate (once per year or when needed)
vdb-cert-ro

# Connect to database
db-blackpoint-dev

# Or use IntelliJ IDEA with saved connection
```

## 7. Certificate Renewal

```bash
# Check certificate expiration
openssl x509 -in ~/.pg/client.crt -noout -dates

# Renew when needed
vdb-cert-ro
```

## 8. Troubleshooting

### "permission denied"

```bash
# Check your Vault policies
vault token lookup

# Should show policies like: pki-readonly, pki-app-blackpoint, etc.
# If missing, check Auth0 roles assignment
```

### "certificate verify failed"

```bash
# Verify CA chain
openssl verify -CAfile ~/.pg/ca.crt ~/.pg/client.crt

# Should output: client.crt: OK
```

### "connection refused"

```bash
# Check Tailscale connection
tailscale status

# Check if database is accessible
nc -zv blackpoint-api-dev.trout-paradise.ts.net 5432
```

### "FATAL: no pg_hba.conf entry"

```bash
# Database not configured for cert auth
# Check pg_hba.conf has: hostssl all all 0.0.0.0/0 cert
```

## 9. Security Notes

- Certificate stored in `~/.pg/` - keep secure
- Private key (`client.key`) has 600 permissions
- Token expires after 7 days - re-login required
- Certificate valid for 1 year by default
- All access logged in Vault audit log
