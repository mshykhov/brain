# RBAC Roles Configuration

## 1. Role Architecture

```
Auth0 Group          Teleport Role        PostgreSQL User       Permissions
─────────────────────────────────────────────────────────────────────────────
db-readonly     →    db-readonly     →    teleport_readonly  →  SELECT only
db-admin        →    db-admin        →    teleport_readwrite →  CRUD + DDL
```

## 2. Create Teleport Roles

### Read-Only Role (Dev only)

```yaml
# role-db-readonly.yaml
kind: role
version: v7
metadata:
  name: db-readonly
spec:
  allow:
    # Only dev databases
    db_labels:
      env: dev
    # Only readonly PostgreSQL user
    db_users:
      - teleport_readonly
    # All databases
    db_names:
      - "*"
  deny:
    # No production access
    db_labels:
      env: prd
```

### DB Admin Role (Dev + Prd)

```yaml
# role-db-admin.yaml
kind: role
version: v7
metadata:
  name: db-admin
spec:
  allow:
    # All environments
    db_labels:
      env: ["dev", "prd"]
    # Read-write PostgreSQL user
    db_users:
      - teleport_readonly
      - teleport_readwrite
    # All databases
    db_names:
      - "*"
  options:
    # Require reason for prd access
    require_session_mfa: false
```

### Access Role (базовая роль для всех)

```yaml
# role-access.yaml
kind: role
version: v7
metadata:
  name: access
spec:
  allow:
    # Allow web UI access
    logins: []
    # No server access by default
    node_labels: {}
```

## 3. Apply Roles

```bash
AUTH_POD=$(kubectl get pod -n teleport -l app=teleport-cluster -o jsonpath='{.items[0].metadata.name}')

# Apply roles
kubectl exec -n teleport $AUTH_POD -- tctl create -f - <<'EOF'
kind: role
version: v7
metadata:
  name: db-readonly
spec:
  allow:
    db_labels:
      env: dev
    db_users:
      - teleport_readonly
    db_names:
      - "*"
  deny:
    db_labels:
      env: prd
---
kind: role
version: v7
metadata:
  name: db-admin
spec:
  allow:
    db_labels:
      env: ["dev", "prd"]
    db_users:
      - teleport_readonly
      - teleport_readwrite
    db_names:
      - "*"
EOF
```

## 4. Update OIDC Connector

```yaml
kind: oidc
version: v3
metadata:
  name: auth0
spec:
  issuer_url: https://login.gaynance.com/
  client_id: <client_id>
  client_secret: <client_secret>
  redirect_url: https://teleport.trout-paradise.ts.net/v1/webapi/oidc/callback

  claims_to_roles:
    # Admin group gets full access
    - claim: "https://teleport/groups"
      value: "db-admin"
      roles:
        - db-admin
        - access

    # Readonly group gets limited access
    - claim: "https://teleport/groups"
      value: "db-readonly"
      roles:
        - db-readonly
        - access

    # All verified users get basic access
    - claim: "email_verified"
      value: "true"
      roles:
        - access
```

## 5. Verify Role Assignment

```bash
# Login via SSO
tsh login --proxy=teleport.trout-paradise.ts.net

# Check assigned roles
tsh status

# Expected output:
# > Profile URL:        https://teleport.trout-paradise.ts.net
# > Logged in as:       user@example.com
# > Roles:              db-admin, access
# > Logins:
# > Valid until:        2024-12-15 06:00:00

# List available databases
tsh db ls

# Connect to test
tsh db connect --db-user=teleport_readonly --db-name=blackpoint blackpoint-api-dev
```

## 6. Optional: Just-in-Time Access

Для production можно настроить approval workflow:

```yaml
kind: role
version: v7
metadata:
  name: db-admin-prd
spec:
  allow:
    db_labels:
      env: prd
    db_users:
      - teleport_readwrite
    db_names:
      - "*"
    request:
      roles:
        - db-admin-prd
      thresholds:
        - approve: 1
          deny: 1
```

## Next Steps

→ [05-client-setup.md](05-client-setup.md)
