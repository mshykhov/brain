# Database Access - Quick Start

## Linux

```bash
# Install
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install vault jq

# Configure (add to ~/.bashrc)
echo 'export VAULT_ADDR="https://vault.trout-paradise.ts.net"' >> ~/.bashrc
source ~/.bashrc

# Login
vault login -method=oidc

# Get credentials
vault read database/creds/blackpoint-dev-readonly
```

## macOS

```bash
# Install
brew install hashicorp/tap/vault jq

# Configure (add to ~/.zshrc)
echo 'export VAULT_ADDR="https://vault.trout-paradise.ts.net"' >> ~/.zshrc
source ~/.zshrc

# Login
vault login -method=oidc

# Get credentials
vault read database/creds/blackpoint-dev-readonly
```

## Windows

```powershell
# Install (choose one)
winget install HashiCorp.Vault jqlang.jq
# or: scoop install vault jq
# or: choco install vault jq

# Configure (run once, then restart PowerShell)
[Environment]::SetEnvironmentVariable("VAULT_ADDR", "https://vault.trout-paradise.ts.net", "User")

# Restart PowerShell, then:

# Login
vault login -method=oidc

# Get credentials
vault read database/creds/blackpoint-dev-readonly
```

## Available Roles

| Role | Access |
|------|--------|
| `blackpoint-dev-readonly` | SELECT only |
| `blackpoint-dev-readwrite` | SELECT, INSERT, UPDATE, DELETE |
| `blackpoint-dev-admin` | SUPERUSER |

## Connect to Database

```bash
# Get credentials and export
eval $(vault read -format=json database/creds/blackpoint-dev-readonly | jq -r '.data | "export PGUSER=\(.username) PGPASSWORD=\(.password)"')

# Connect
psql "host=blackpoint-db-dev.trout-paradise.ts.net port=5432 dbname=blackpoint sslmode=require"
```
