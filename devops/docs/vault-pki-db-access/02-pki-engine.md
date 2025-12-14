# PKI Engine Configuration

## 1. Enable PKI Secrets Engine

```bash
VAULT_POD="vault-0"

# Enable root PKI (for CA)
kubectl exec -n vault $VAULT_POD -- vault secrets enable -path=pki pki

# Set max TTL to 10 years for root CA
kubectl exec -n vault $VAULT_POD -- vault secrets tune -max-lease-ttl=87600h pki

# Enable intermediate PKI (for issuing certs)
kubectl exec -n vault $VAULT_POD -- vault secrets enable -path=pki_int pki

# Set max TTL to 5 years for intermediate
kubectl exec -n vault $VAULT_POD -- vault secrets tune -max-lease-ttl=43800h pki_int
```

## 2. Generate Root CA

```bash
# Generate root CA certificate (10 years)
kubectl exec -n vault $VAULT_POD -- vault write -field=certificate pki/root/generate/internal \
    common_name="smhomelab-root-ca" \
    issuer_name="root-2024" \
    ttl=87600h > root_ca.crt

# Configure CA and CRL URLs
kubectl exec -n vault $VAULT_POD -- vault write pki/config/urls \
    issuing_certificates="https://vault.trout-paradise.ts.net/v1/pki/ca" \
    crl_distribution_points="https://vault.trout-paradise.ts.net/v1/pki/crl"
```

## 3. Generate Intermediate CA

```bash
# Generate CSR for intermediate
kubectl exec -n vault $VAULT_POD -- vault write -format=json pki_int/intermediate/generate/internal \
    common_name="smhomelab-intermediate-ca" \
    issuer_name="intermediate-2024" \
    | jq -r '.data.csr' > pki_int.csr

# Sign intermediate with root CA (5 years)
kubectl exec -n vault $VAULT_POD -- vault write -format=json pki/root/sign-intermediate \
    csr=@pki_int.csr \
    format=pem_bundle \
    ttl=43800h \
    | jq -r '.data.certificate' > intermediate.crt

# Import signed intermediate
kubectl exec -n vault $VAULT_POD -- vault write pki_int/intermediate/set-signed \
    certificate=@intermediate.crt
```

## 4. Create PKI Roles

### Role: db-readonly (1 year certs)

```bash
kubectl exec -n vault $VAULT_POD -- vault write pki_int/roles/db-readonly \
    allowed_domains="readonly.db.local" \
    allow_any_name=true \
    allow_subdomains=false \
    max_ttl=8760h \
    ttl=8760h \
    key_type=rsa \
    key_bits=2048 \
    require_cn=true \
    cn_validations="disabled"
```

### Role: db-readwrite (1 year certs)

```bash
kubectl exec -n vault $VAULT_POD -- vault write pki_int/roles/db-readwrite \
    allowed_domains="readwrite.db.local" \
    allow_any_name=true \
    allow_subdomains=false \
    max_ttl=8760h \
    ttl=8760h \
    key_type=rsa \
    key_bits=2048 \
    require_cn=true \
    cn_validations="disabled"
```

### Role: db-admin (1 year certs)

```bash
kubectl exec -n vault $VAULT_POD -- vault write pki_int/roles/db-admin \
    allowed_domains="admin.db.local" \
    allow_any_name=true \
    allow_subdomains=false \
    max_ttl=8760h \
    ttl=8760h \
    key_type=rsa \
    key_bits=2048 \
    require_cn=true \
    cn_validations="disabled"
```

## 5. Export CA Certificate

Для настройки баз данных нужен CA cert:

```bash
# Get CA certificate
kubectl exec -n vault $VAULT_POD -- vault read -field=certificate pki_int/cert/ca > ca.crt

# Create K8s secret with CA (для CNPG и других DB)
kubectl create secret generic vault-ca \
    --from-file=ca.crt=ca.crt \
    -n default
```

## 6. Test Certificate Issuance

```bash
# Issue test certificate
kubectl exec -n vault $VAULT_POD -- vault write -format=json pki_int/issue/db-readonly \
    common_name="test@company.com" \
    ttl=24h

# Output includes:
# - certificate
# - issuing_ca
# - ca_chain
# - private_key
# - serial_number
```

## 7. Terraform Configuration (GitOps)

`terraform/vault-pki.tf`:

```hcl
resource "vault_mount" "pki" {
  path                      = "pki"
  type                      = "pki"
  max_lease_ttl_seconds     = 315360000  # 10 years
}

resource "vault_mount" "pki_int" {
  path                      = "pki_int"
  type                      = "pki"
  max_lease_ttl_seconds     = 157680000  # 5 years
}

resource "vault_pki_secret_backend_role" "db_readonly" {
  backend          = vault_mount.pki_int.path
  name             = "db-readonly"
  ttl              = 31536000  # 1 year
  max_ttl          = 31536000
  allow_any_name   = true
  key_type         = "rsa"
  key_bits         = 2048
}

resource "vault_pki_secret_backend_role" "db_readwrite" {
  backend          = vault_mount.pki_int.path
  name             = "db-readwrite"
  ttl              = 31536000
  max_ttl          = 31536000
  allow_any_name   = true
  key_type         = "rsa"
  key_bits         = 2048
}

resource "vault_pki_secret_backend_role" "db_admin" {
  backend          = vault_mount.pki_int.path
  name             = "db-admin"
  ttl              = 31536000
  max_ttl          = 31536000
  allow_any_name   = true
  key_type         = "rsa"
  key_bits         = 2048
}
```

## Next Steps

→ [03-auth0-oidc.md](03-auth0-oidc.md)
