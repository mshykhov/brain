# Cloudflare Tunnel - Full GitOps

## Overview

Миграция с remotely-managed tunnel (Dashboard) на locally-managed tunnel (config.yaml в Git).

**Преимущества:**
- Вся конфигурация в Git
- Infrastructure as Code
- Нет зависимости от Cloudflare Dashboard

**Официальная документация:**
- [Create locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/)
- [Configuration file](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/local-management/configuration-file/)
- [Kubernetes example](https://github.com/cloudflare/argo-tunnel-examples/blob/master/named-tunnel-k8s/cloudflared.yaml)

## Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                            Git Repository                              │
│  ┌─────────────────────┐  ┌─────────────────────┐                     │
│  │ config.yaml         │  │ Doppler             │                     │
│  │ - ingress rules     │  │ - CF_TUNNEL_CREDS   │                     │
│  │ - tunnel UUID       │  │   (credentials.json)│                     │
│  └─────────────────────┘  └─────────────────────┘                     │
└───────────────────────────────────────────────────────────────────────┘
                │                        │
                ▼                        ▼
┌───────────────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                             │
│  ┌─────────────────────┐  ┌─────────────────────┐                     │
│  │ ConfigMap           │  │ Secret              │                     │
│  │ cloudflared-config  │  │ tunnel-credentials  │ ← ExternalSecret    │
│  └─────────────────────┘  └─────────────────────┘                     │
│                │                        │                              │
│                └────────────┬───────────┘                              │
│                             ▼                                          │
│                   ┌─────────────────┐                                  │
│                   │   cloudflared   │                                  │
│                   │   Deployment    │                                  │
│                   └────────┬────────┘                                  │
│                            │                                           │
│                            ▼                                           │
│                   ┌─────────────────┐                                  │
│                   │  NGINX Ingress  │                                  │
│                   └────────┬────────┘                                  │
│                            │                                           │
│              ┌─────────────┼─────────────┐                            │
│              ▼             ▼             ▼                            │
│      ┌───────────┐  ┌───────────┐  ┌───────────┐                     │
│      │ API Pods  │  │ UI Pods   │  │ Other     │                     │
│      └───────────┘  └───────────┘  └───────────┘                     │
└───────────────────────────────────────────────────────────────────────┘
```

## Step 1: Create Locally-Managed Tunnel

### 1.1 Install cloudflared CLI

**macOS:**
```bash
brew install cloudflared
```

**Linux (Debian/Ubuntu):**
```bash
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | sudo tee /usr/share/keyrings/cloudflare-public-v2.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main" | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install cloudflared
```

**Windows:**
```powershell
winget install Cloudflare.cloudflared
```

### 1.2 Authenticate

```bash
cloudflared tunnel login
```

Откроется браузер для авторизации. После успеха появится `~/.cloudflared/cert.pem`.

### 1.3 Create Tunnel

```bash
cloudflared tunnel create k8s-prd-tunnel
```

**Output:**
```
Tunnel credentials written to /Users/myron/.cloudflared/<TUNNEL_UUID>.json
Created tunnel k8s-prd-tunnel with id <TUNNEL_UUID>
```

> **IMPORTANT:** Сохрани credentials.json - он понадобится для Doppler!

### 1.4 Get Tunnel UUID

```bash
cloudflared tunnel list
```

**Output:**
```
ID                                   NAME            CREATED
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx k8s-prd-tunnel  2024-12-04T10:00:00Z
```

## Step 2: Store Credentials in Doppler

### 2.1 Encode credentials.json

```bash
cat ~/.cloudflared/<TUNNEL_UUID>.json | base64 -w0
```

### 2.2 Add to Doppler

В Doppler Dashboard → `shared` config:

| Key | Value |
|-----|-------|
| `CF_TUNNEL_CREDENTIALS` | (base64 encoded credentials.json) |

> **Note:** credentials.json содержит AccountTag, TunnelSecret, TunnelID - достаточно для аутентификации.

## Step 3: Create DNS Records

```bash
# Route hostnames to tunnel
cloudflared tunnel route dns k8s-prd-tunnel api.untrustedonline.org
cloudflared tunnel route dns k8s-prd-tunnel untrustedonline.org
```

Это создаёт CNAME записи в Cloudflare DNS:
- `api.untrustedonline.org` → `<TUNNEL_UUID>.cfargotunnel.com`
- `untrustedonline.org` → `<TUNNEL_UUID>.cfargotunnel.com`

## Step 4: Update Helm Chart

### 4.1 ExternalSecret for Credentials

`charts/credentials/templates/cloudflare.yaml`:
```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflare-tunnel-credentials
  namespace: cloudflare
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: doppler-shared
  target:
    name: tunnel-credentials
    creationPolicy: Owner
    template:
      data:
        credentials.json: "{{ .credentials | base64decode }}"
  data:
    - secretKey: credentials
      remoteRef:
        key: CF_TUNNEL_CREDENTIALS
```

### 4.2 ConfigMap with Ingress Rules

`charts/cloudflare-tunnel/templates/configmap.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudflared-config
  namespace: cloudflare
data:
  config.yaml: |
    tunnel: {{ .Values.tunnel.uuid }}
    credentials-file: /etc/cloudflared/creds/credentials.json
    metrics: 0.0.0.0:2000
    no-autoupdate: true

    ingress:
      {{- range .Values.ingress }}
      - hostname: {{ .hostname }}
        service: {{ .service }}
      {{- end }}
      - service: http_status:404
```

### 4.3 values.yaml

```yaml
tunnel:
  uuid: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

replicas: 2

image:
  repository: cloudflare/cloudflared
  tag: "2024.11.1"
  pullPolicy: IfNotPresent

resources:
  requests:
    cpu: 10m
    memory: 64Mi
  limits:
    cpu: 100m
    memory: 128Mi

# Ingress rules - all routing config in Git!
ingress:
  - hostname: api.untrustedonline.org
    service: http://nginx-ingress-ingress-nginx-controller.nginx-ingress.svc.cluster.local:80
  - hostname: untrustedonline.org
    service: http://nginx-ingress-ingress-nginx-controller.nginx-ingress.svc.cluster.local:80
```

### 4.4 deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: cloudflare
spec:
  replicas: {{ .Values.replicas }}
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          args:
            - tunnel
            - --config
            - /etc/cloudflared/config/config.yaml
            - run
          ports:
            - name: metrics
              containerPort: 2000
          volumeMounts:
            - name: config
              mountPath: /etc/cloudflared/config
              readOnly: true
            - name: creds
              mountPath: /etc/cloudflared/creds
              readOnly: true
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet:
              path: /ready
              port: 2000
            initialDelaySeconds: 10
            periodSeconds: 10
      volumes:
        - name: config
          configMap:
            name: cloudflared-config
        - name: creds
          secret:
            secretName: tunnel-credentials
```

## Step 5: Delete Old Tunnel (Optional)

После успешной миграции можно удалить старый remotely-managed tunnel:

1. Cloudflare Dashboard → Zero Trust → Networks → Tunnels
2. Выбрать старый tunnel
3. Delete tunnel

> **Note:** Сначала убедись что новый tunnel работает!

## Step 6: Cleanup Doppler

Удалить старый `CF_TUNNEL_TOKEN` из Doppler `shared` config (больше не нужен).

## Verification

```bash
# Check pods running
kubectl get pods -n cloudflare

# Check tunnel connected
kubectl logs -n cloudflare -l app=cloudflared | grep "Connection"

# Expect: "Connection registered"

# Test endpoints
curl https://api.untrustedonline.org/actuator/health
curl https://untrustedonline.org
```

## Troubleshooting

### Error: "credentials file not found"

```bash
# Check secret mounted
kubectl exec -n cloudflare -it deployment/cloudflared -- ls -la /etc/cloudflared/creds/

# Check secret content
kubectl get secret -n cloudflare tunnel-credentials -o jsonpath='{.data.credentials\.json}' | base64 -d
```

### Error: "failed to parse config"

```bash
# Check configmap
kubectl get configmap -n cloudflare cloudflared-config -o yaml

# Validate YAML syntax
```

### Error: "tunnel not found"

```bash
# Verify tunnel exists
cloudflared tunnel list

# Verify tunnel UUID in values.yaml matches
```

## Migration Checklist

- [ ] Install cloudflared CLI
- [ ] Run `cloudflared tunnel login`
- [ ] Create tunnel: `cloudflared tunnel create k8s-prd-tunnel`
- [ ] Save credentials.json
- [ ] Add base64-encoded credentials to Doppler (CF_TUNNEL_CREDENTIALS)
- [ ] Create DNS routes: `cloudflared tunnel route dns ...`
- [ ] Update Helm chart with new templates
- [ ] Update values.yaml with tunnel UUID and ingress rules
- [ ] Commit and push to Git
- [ ] Wait for ArgoCD sync
- [ ] Verify tunnel working
- [ ] Delete old remotely-managed tunnel from Dashboard
- [ ] Remove old CF_TUNNEL_TOKEN from Doppler
