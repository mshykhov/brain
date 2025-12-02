# Phase 5 Troubleshooting

## Quick Checks

```bash
# All pods healthy?
kubectl get pods -A | grep -v Running

# oauth2-proxy logs
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy -f

# NGINX logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f

# Tailscale operator logs
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator -f
```

## Common Issues

### 1. Auth0 Login не работает

#### "Unable to verify OIDC token"

**Причина:** Неверный AUTH0_DOMAIN

**Решение:**
```bash
# Проверь domain (без https://)
kubectl get secret -n oauth2-proxy auth0-oidc-credentials -o jsonpath='{.data.client-id}' | base64 -d

# Должен быть: dev-xxx.us.auth0.com (без https://)
```

#### "Callback URL mismatch"

**Причина:** URL в Auth0 не совпадает с реальным

**Решение:**
1. Auth0 Dashboard → Applications → oauth2-proxy → Settings
2. Проверь Allowed Callback URLs:
   ```
   https://argocd.<tailnet>.ts.net/oauth2/callback
   https://longhorn.<tailnet>.ts.net/oauth2/callback
   ```

### 2. Groups не работают

#### 403 после успешного login

**Причина:** Groups не передаются в token

**Проверка:**
```bash
# Логи oauth2-proxy должны показывать groups
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy | grep -i group
```

**Решения:**

1. **Auth0 Action не deployed:**
   - Auth0 → Actions → Library → Find "Add Groups to Token"
   - Должен быть Status: Deployed

2. **Action не в Flow:**
   - Auth0 → Actions → Flows → Login
   - Должен быть "Add Groups to Token" в flow

3. **User не имеет roles:**
   - Auth0 → User Management → Users → (user) → Roles
   - Должны быть назначены роли

4. **Неверный groups claim:**
   ```bash
   # Проверь oauth2-proxy config
   kubectl get cm -n oauth2-proxy oauth2-proxy -o yaml | grep groups_claim
   # Должно быть: oidc_groups_claim = "https://ns/groups"
   ```

### 3. Tailscale Issues

#### Operator не подключается к tailnet

```bash
# Проверь OAuth secret
kubectl get secret -n tailscale tailscale-oauth -o yaml

# Проверь логи
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator

# Common: Invalid OAuth credentials
```

**Решение:**
1. Tailscale Admin → Settings → OAuth clients
2. Verify Client ID and Secret
3. Verify scopes: Devices Core, Auth Keys, Services (all Write)

#### Tailscale proxy не создаётся

```bash
# Проверь Tailscale Ingress
kubectl get ingress -n ingress-nginx

# Проверь events
kubectl describe ingress argocd-tailscale -n ingress-nginx
```

**Common причины:**
- IngressClass `tailscale` не существует
- Operator не ready

### 4. oauth2-proxy Issues

#### Redis connection failed

```bash
# Проверь Redis pods
kubectl get pods -n oauth2-proxy | grep redis

# Проверь sentinel
kubectl exec -n oauth2-proxy oauth2-proxy-redis-server-0 -- redis-cli -a $REDIS_PASSWORD ping
```

**Решение:**
```bash
# Рестарт redis
kubectl rollout restart statefulset -n oauth2-proxy oauth2-proxy-redis-server
```

#### "No session found"

**Причина:** Redis не работает или cookie expires

**Решения:**
1. Проверь Redis connectivity
2. Clear browser cookies
3. Проверь `cookie_domains` matches host

### 5. NGINX Issues

#### 502 Bad Gateway

**Причины:**
1. oauth2-proxy не running
2. Backend service не running
3. Wrong service name

```bash
# Проверь oauth2-proxy
kubectl get pods -n oauth2-proxy

# Проверь backend
kubectl get svc -n argocd argocd-server

# Test connectivity
kubectl exec -n ingress-nginx deploy/nginx-ingress-ingress-nginx-controller -- \
  curl -s http://oauth2-proxy.oauth2-proxy.svc.cluster.local/ping
```

#### Redirect loop

**Причины:**
1. Cookie domain mismatch
2. Wrong auth-signin URL

**Решение:**
1. Clear browser cookies
2. Проверь `cookie_domains` в oauth2-proxy config

### 6. ArgoCD Issues

#### Login page вместо UI

**Причина:** Anonymous access не enabled

```bash
# Проверь argocd-cm
kubectl get cm -n argocd argocd-cm -o yaml | grep anonymous
# Должно быть: users.anonymous.enabled: "true"

# Рестарт если изменил
kubectl rollout restart deploy -n argocd argocd-server
```

#### Sync постоянно OutOfSync

**Причина:** ExternalSecrets добавляют default values

**Решение:** `ignoreDifferences` в Application:
```yaml
ignoreDifferences:
  - group: external-secrets.io
    kind: ExternalSecret
    jqPathExpressions:
      - .spec.data[].remoteRef.conversionStrategy
```

### 7. Doppler/ExternalSecrets

#### Secret не создаётся

```bash
# Проверь ExternalSecret status
kubectl get externalsecret -A
kubectl describe externalsecret <name> -n <namespace>

# Проверь ClusterSecretStore
kubectl get clustersecretstore
kubectl describe clustersecretstore doppler-shared
```

**Common причины:**
- Doppler Service Token expired
- Wrong secret key name in Doppler

## Debugging Commands

### Full status check

```bash
# All resources
kubectl get pods,svc,ingress,externalsecret -A

# oauth2-proxy specific
kubectl get all -n oauth2-proxy

# Tailscale specific
kubectl get all -n tailscale
kubectl get ingressclass
```

### Logs

```bash
# oauth2-proxy
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy --tail=100 -f

# NGINX
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 -f

# Tailscale
kubectl logs -n tailscale -l app.kubernetes.io/name=tailscale-operator --tail=100 -f

# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=100 -f
```

### Test auth flow manually

```bash
# Get oauth2-proxy pod
POD=$(kubectl get pods -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy -o jsonpath='{.items[0].metadata.name}')

# Test auth endpoint
kubectl exec -n oauth2-proxy $POD -- wget -qO- http://localhost:4180/ping
```

## Lessons Learned

### 1. ArgoCD OIDC vs oauth2-proxy

**Problem:** Сложность двойной auth (oauth2-proxy + ArgoCD OIDC)

**Solution:** Anonymous ArgoCD за oauth2-proxy

### 2. Auth0 namespaced claims

**Problem:** Groups пустые несмотря на roles

**Solution:** Auth0 требует namespace для custom claims (`https://ns/groups`)

### 3. proxyVarsAsSecrets

**Problem:** oauth2-proxy chart создаёт дефолтные env vars конфликтующие с кастомными

**Solution:** `proxyVarsAsSecrets: false` + extraEnv

### 4. Reloader + ArgoCD

**Problem:** Reloader вызывает бесконечные sync loops

**Solution:** Не использовать Reloader для ArgoCD ConfigMaps

### 5. ignoreDifferences для ESO

**Problem:** ArgoCD показывает OutOfSync из-за ESO default values

**Solution:** jqPathExpressions для игнорирования ESO defaults
