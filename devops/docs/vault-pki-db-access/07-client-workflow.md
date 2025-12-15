# Developer Workflow

## 1. Prerequisites

### Install Vault CLI

```bash
# macOS
brew install hashicorp/tap/vault

# Windows (PowerShell) - choose one:
scoop install vault          # Option 1: Scoop
choco install vault          # Option 2: Chocolatey
winget install HashiCorp.Vault  # Option 3: Winget

# Linux (Debian/Ubuntu)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault
```

### Install jq (required for shell aliases)

```bash
# macOS
brew install jq

# Windows
scoop install jq
choco install jq
winget install jqlang.jq

# Linux
sudo apt-get install jq
```

### Configure Vault Address

```bash
# Linux/macOS: Add to ~/.bashrc or ~/.zshrc
export VAULT_ADDR="https://vault.trout-paradise.ts.net"
```

```powershell
# Windows PowerShell: Add to $PROFILE
$env:VAULT_ADDR = "https://vault.trout-paradise.ts.net"

# Or set permanently:
[Environment]::SetEnvironmentVariable("VAULT_ADDR", "https://vault.trout-paradise.ts.net", "User")
```

## 2. Login via Auth0

```bash
# Opens browser for Auth0 SSO
vault login -method=oidc

# Success output:
# Success! You are now authenticated.
# token          hvs.xxx
# token_accessor xxx
# token_policies ["default" "database-blackpoint-dev-readonly" ...]
```

## 3. Get Database Credentials

### One-liner

```bash
# Get credentials and set environment variables
eval $(vault read -format=json database/creds/blackpoint-dev-readonly | \
    jq -r '.data | "export PGUSER=\(.username) PGPASSWORD=\(.password)"')
echo "Credentials valid for 24h"
```

### Step by Step

```bash
# Request credentials
vault read database/creds/blackpoint-dev-readonly

# Output:
# Key                Value
# ---                -----
# lease_id           database/creds/blackpoint-dev-readonly/abc123
# lease_duration     24h
# username           v-oidc-readonly-HfgL2k
# password           A1b2C3d4-xxxxx

# Set environment
export PGUSER="v-oidc-readonly-HfgL2k"
export PGPASSWORD="A1b2C3d4-xxxxx"
```

## 4. Connect to Database

### psql

```bash
psql "host=blackpoint-db-dev.trout-paradise.ts.net \
      port=5432 \
      dbname=blackpoint \
      sslmode=require"
```

### IntelliJ IDEA / DataGrip

1. **Database** → **+** → **Data Source** → **PostgreSQL**
2. Configure:
   ```
   Host: blackpoint-db-dev.trout-paradise.ts.net
   Port: 5432
   Database: blackpoint
   User: <from vault read>
   Password: <from vault read>
   ```
3. **SSH/SSL** tab:
   - ✅ Use SSL
   - Mode: `require`
4. **Test Connection** → OK

**Note:** Credentials expire in 24h. Get new ones with `vault read database/creds/...`

## 5. Shell Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Vault shortcuts
export VAULT_ADDR="https://vault.trout-paradise.ts.net"
alias vlogin='vault login -method=oidc'

# Get DB credentials and set env vars
vdb() {
    local db=$1
    local access=${2:-readonly}
    local role="${db}-${access}"
    
    echo "Getting credentials for $role..."
    local creds=$(vault read -format=json "database/creds/$role" 2>/dev/null)
    
    if [ -z "$creds" ]; then
        echo "Error: Could not get credentials for $role"
        echo "Available roles: blackpoint-dev-readonly, blackpoint-dev-readwrite, notifier-dev-readonly, etc."
        return 1
    fi
    
    export PGUSER=$(echo $creds | jq -r '.data.username')
    export PGPASSWORD=$(echo $creds | jq -r '.data.password')
    
    local ttl=$(echo $creds | jq -r '.lease_duration')
    echo "Credentials set: PGUSER=$PGUSER (TTL: ${ttl}s)"
}

# Show my Vault info (identity, policies, available roles)
vinfo() {
    echo "=== Token Info ==="
    vault token lookup -format=json 2>/dev/null | jq -r '
        "Policies: \(.data.policies | join(", "))",
        "TTL: \(.data.ttl)s",
        "Expires: \(.data.expire_time)"'

    echo -e "\n=== Available Database Roles ==="
    vault list -format=json database/roles 2>/dev/null | jq -r '.[]' || echo "No access to list roles"
}

# Quick connect to databases
db-blackpoint-dev() {
    vdb blackpoint-dev ${1:-readonly}
    psql "host=blackpoint-db-dev.trout-paradise.ts.net port=5432 dbname=blackpoint sslmode=require"
}

db-blackpoint-prd() {
    vdb blackpoint-prd ${1:-readonly}
    psql "host=blackpoint-db-prd.trout-paradise.ts.net port=5432 dbname=blackpoint sslmode=require"
}

db-notifier-dev() {
    vdb notifier-dev ${1:-readonly}
    psql "host=notifier-db-dev.trout-paradise.ts.net port=5432 dbname=notifier sslmode=require"
}
```

## 6. Daily Workflow

```bash
# Morning: login (once per 7 days)
vlogin

# Check your access
vinfo
# Output:
# === Token Info ===
# Policies: default, self-service, database-blackpoint-dev-admin
# TTL: 604800s
# Expires: 2024-01-22T10:00:00Z
#
# === Available Database Roles ===
# blackpoint-dev-admin
# blackpoint-dev-readonly
# blackpoint-dev-readwrite

# Get credentials and connect (once per day)
db-blackpoint-dev              # readonly access
db-blackpoint-dev readwrite    # readwrite access

# Or manually:
vdb blackpoint-dev readonly
psql -h blackpoint-db-dev.trout-paradise.ts.net -d blackpoint
```

## 7. Credential Lifecycle

```
Timeline:
─────────────────────────────────────────────────────────────
T=0h:   vault read database/creds/... → new credentials
T=0h:   Connect to database with credentials
T=24h:  Credentials expire, DB connection drops
T=24h+: Get new credentials with vault read
─────────────────────────────────────────────────────────────

If Auth0 role removed:
T=0h:   User has credentials (24h TTL)
T=1h:   Admin removes role in Auth0
T=2h:   User tries vault read → DENIED
T=24h:  Old credentials expire → complete access loss
```

## 8. Troubleshooting

### "permission denied"

```bash
# Check your Vault policies
vault token lookup

# Should show policies like: database-blackpoint-dev-readonly
# If missing, check Auth0 roles assignment
```

### "no such role"

```bash
# List available database roles
vault list database/roles

# Check you have correct role format: {app}-{env}-{access}
# Examples: blackpoint-dev-readonly, notifier-prd-readwrite
```

### "connection refused"

```bash
# Check Tailscale connection
tailscale status

# Check if database is accessible
nc -zv blackpoint-db-dev.trout-paradise.ts.net 5432
```

### "FATAL: password authentication failed"

```bash
# Credentials may have expired, get new ones
vdb blackpoint-dev readonly
```

## 9. Security Notes

- Credentials auto-expire after 24 hours
- Token expires after 7 days - re-login required
- All credential requests logged in Vault audit log
- Role changes in Auth0 take effect on next credential request
- No certificates to manage - just username/password
