# Database Configuration for mTLS

## 1. CloudNativePG (PostgreSQL)

### Export Vault CA

```bash
# Get CA from Vault
kubectl exec -n vault vault-0 -- vault read -field=certificate pki_int/cert/ca > vault-ca.crt

# Create secret in database namespace
kubectl create secret generic vault-ca \
    --from-file=ca.crt=vault-ca.crt \
    -n blackpoint-api-dev
```

### Update CNPG Cluster

`infrastructure/charts/cnpg-cluster/templates/cluster.yaml`:

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: {{ .Release.Name }}-cluster
spec:
  instances: 2

  postgresql:
    parameters:
      ssl: "on"
      ssl_ca_file: "/etc/ssl/vault/ca.crt"

    pg_hba:
      # Allow cert auth from Tailscale network
      - hostssl all all 100.64.0.0/10 cert
      - hostssl all all 0.0.0.0/0 cert

  # Mount Vault CA
  projectedVolumeTemplate:
    sources:
      - secret:
          name: vault-ca
          items:
            - key: ca.crt
              path: vault/ca.crt

  # Certificate configuration
  certificates:
    # Server cert (CNPG manages)
    serverTLSSecret: {{ .Release.Name }}-server-tls
    serverCASecret: {{ .Release.Name }}-server-ca

    # Client CA (Vault CA for client auth)
    clientCASecret: vault-ca
```

### Create PostgreSQL Users

```bash
# Connect to PostgreSQL
kubectl exec -it -n blackpoint-api-dev blackpoint-api-dev-cluster-1 -- psql -U postgres

-- Create user for readonly access (matches cert CN pattern)
CREATE ROLE readonly_user WITH LOGIN;
GRANT CONNECT ON DATABASE blackpoint TO readonly_user;
GRANT USAGE ON SCHEMA public TO readonly_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly_user;

-- Create user for readwrite access
CREATE ROLE readwrite_user WITH LOGIN;
GRANT CONNECT ON DATABASE blackpoint TO readwrite_user;
GRANT USAGE ON SCHEMA public TO readwrite_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO readwrite_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO readwrite_user;

-- Create admin user
CREATE ROLE admin_user WITH LOGIN SUPERUSER;
```

### Configure pg_ident.conf (CN mapping)

```yaml
# In CNPG cluster spec
postgresql:
  pg_ident.conf: |
    # Map certificate CN to PostgreSQL user
    # MAPNAME    SYSTEM-USERNAME           PG-USERNAME
    vault_users  /^(.*)@.*$/               readonly_user
    vault_admin  admin@company.com         admin_user
```

## 2. MySQL/MariaDB

### Configure MySQL for mTLS

```sql
-- Require SSL with client certificate
ALTER USER 'readonly_user'@'%' REQUIRE X509;
ALTER USER 'readwrite_user'@'%' REQUIRE X509;
ALTER USER 'admin_user'@'%' REQUIRE X509;

-- Or require specific issuer
ALTER USER 'readonly_user'@'%'
  REQUIRE ISSUER '/CN=smhomelab-intermediate-ca';
```

### MySQL Configuration

```ini
# my.cnf
[mysqld]
ssl-ca=/etc/mysql/ssl/ca.crt
ssl-cert=/etc/mysql/ssl/server.crt
ssl-key=/etc/mysql/ssl/server.key
require_secure_transport=ON
```

## 3. MongoDB

### Configure MongoDB for mTLS

```yaml
# mongod.conf
net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb.pem
    CAFile: /etc/ssl/vault-ca.crt
    allowConnectionsWithoutCertificates: false

security:
  authorization: enabled
```

### Create MongoDB Users

```javascript
db.createUser({
  user: "readonly_user",
  roles: [{ role: "read", db: "mydb" }]
});

db.createUser({
  user: "readwrite_user",
  roles: [{ role: "readWrite", db: "mydb" }]
});
```

## 4. Redis

### Configure Redis for mTLS

```conf
# redis.conf
tls-port 6379
port 0
tls-cert-file /etc/ssl/redis.crt
tls-key-file /etc/ssl/redis.key
tls-ca-cert-file /etc/ssl/vault-ca.crt
tls-auth-clients yes
```

## 5. Verify Database mTLS

### Test PostgreSQL Connection

```bash
# Get certificate from Vault
vault write -format=json pki_int/issue/db-readonly \
    common_name="test@company.com" \
    ttl="1h" > cert.json

jq -r '.data.certificate' cert.json > client.crt
jq -r '.data.private_key' cert.json > client.key
jq -r '.data.ca_chain[0]' cert.json > ca.crt

# Test connection
psql "host=blackpoint-api-dev.trout-paradise.ts.net \
      port=5432 \
      dbname=blackpoint \
      user=readonly_user \
      sslmode=verify-full \
      sslcert=client.crt \
      sslkey=client.key \
      sslrootcert=ca.crt"
```

## Next Steps

→ [06-tailscale-expose.md](06-tailscale-expose.md)
