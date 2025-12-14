# Client Setup (tsh + IntelliJ IDEA)

## 1. Install tsh

### Windows

```powershell
# Via Scoop
scoop bucket add extras
scoop install teleport

# Or download MSI from:
# https://goteleport.com/download/
```

### macOS

```bash
brew install teleport
```

### Linux

```bash
curl https://goteleport.com/static/install.sh | bash -s 18.5.1
```

## 2. Login via SSO

```bash
# First time login
tsh login --proxy=teleport.trout-paradise.ts.net

# Browser opens → Auth0 login → callback
# Token saved to ~/.tsh/

# Check status
tsh status
```

## 3. List Available Databases

```bash
tsh db ls

# Output:
# Name                 Description  Allowed Users     Labels
# -------------------- ------------ ----------------- ------
# blackpoint-api-dev                [teleport_*]      env=dev
# blackpoint-api-prd                [teleport_*]      env=prd
# notifier-dev                      [teleport_*]      env=dev
# notifier-prd                      [teleport_*]      env=prd
```

## 4. Start Database Proxy

```bash
# Dev database (readonly)
tsh proxy db --db-user=teleport_readonly --db-name=blackpoint blackpoint-api-dev

# Output:
# Started authenticated tunnel for the PostgreSQL database "blackpoint-api-dev"
# at 127.0.0.1:52691
#
# Use the following command to connect:
#   psql "host=127.0.0.1 port=52691 dbname=blackpoint user=teleport_readonly"

# Keep this terminal open!
```

## 5. Configure IntelliJ IDEA

### Add Data Source

1. **View** → **Tool Windows** → **Database**
2. **+** → **Data Source** → **PostgreSQL**
3. Configure:

```
Name: blackpoint-api-dev (Teleport)
Host: localhost
Port: 52691  (from tsh proxy output)
Database: blackpoint
User: teleport_readonly
Password: (leave empty)
```

4. **Test Connection** → Should work!
5. **OK**

### Save Multiple Connections

Создай Data Sources для каждой комбинации:

| Name | DB | User | Use Case |
|------|-----|------|----------|
| blackpoint-dev-ro | blackpoint-api-dev | teleport_readonly | Dev read |
| blackpoint-dev-rw | blackpoint-api-dev | teleport_readwrite | Dev write |
| blackpoint-prd-ro | blackpoint-api-prd | teleport_readonly | Prd read |

## 6. Daily Workflow

```bash
# Morning: login (once per 12h)
tsh login --proxy=teleport.trout-paradise.ts.net

# Start proxy for needed database
tsh proxy db --db-user=teleport_readonly --db-name=blackpoint blackpoint-api-dev

# Use IDEA to query
# ...

# When done, Ctrl+C to stop proxy
```

## 7. Shell Aliases (Optional)

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Teleport shortcuts
alias tlogin='tsh login --proxy=teleport.trout-paradise.ts.net'
alias tdb-dev='tsh proxy db --db-user=teleport_readonly --db-name=blackpoint blackpoint-api-dev'
alias tdb-prd='tsh proxy db --db-user=teleport_readonly --db-name=blackpoint blackpoint-api-prd'
alias tdb-dev-rw='tsh proxy db --db-user=teleport_readwrite --db-name=blackpoint blackpoint-api-dev'
```

Usage:
```bash
tlogin     # SSO login
tdb-dev    # Start dev proxy
```

## 8. Teleport Connect (GUI Alternative)

Если не хочешь CLI:

1. Download [Teleport Connect](https://goteleport.com/download/)
2. Add cluster: `teleport.trout-paradise.ts.net`
3. Login via Auth0
4. Click database → Start Connection
5. Copy connection string to IDEA

## Troubleshooting

### "Access denied"

```bash
# Check your roles
tsh status

# Check available db_users for you
tsh db ls -v
```

### "Connection refused"

```bash
# Make sure proxy is running
tsh proxy db ...

# Check port in output
```

### Token expired

```bash
# Re-login
tsh login --proxy=teleport.trout-paradise.ts.net
```

## Security Notes

- Token stored in `~/.tsh/` - keep secure
- Proxy runs locally - no DB credentials exposed
- All queries logged in Teleport audit log
- Session expires after 12h by default
