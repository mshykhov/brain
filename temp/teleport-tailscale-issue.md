# Teleport + Tailscale Integration Issue

## Goal
Expose Teleport cluster via Tailscale for secure database access (passwordless via Auth0 SSO).

## Architecture
- Teleport cluster deployed via Helm chart `teleport-cluster` v18.5.1
- Expose via Tailscale LoadBalancer (TCP passthrough, not HTTP)
- Teleport uses multiplex mode (SSH + gRPC + HTTPS on port 443)

## Problem
Tailscale proxy pod constantly restarts with error:
```
machineAuthorized=false; authURL=true
invalid state: tailscaled daemon started with a config file, but tailscale is not logged in: ensure you pass a valid auth key in the config file.
```

Additionally, constant `optimistic lock error` in Tailscale operator logs when ArgoCD selfHeal is enabled.

## Approaches Tried

### 1. LoadBalancer directly on Teleport service
**File:** `helm-values/core/teleport-cluster.yaml`
```yaml
service:
  type: LoadBalancer
  spec:
    loadBalancerClass: tailscale
annotations:
  service:
    tailscale.com/hostname: teleport
```
**Result:** Optimistic lock conflict between Teleport Helm chart reconciliation and Tailscale operator.

### 2. Separate LoadBalancer via protected-services
**File:** `charts/protected-services/templates/tailscale-direct.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}-ts-lb
  namespace: {{ $service.namespace }}
  annotations:
    tailscale.com/hostname: {{ $name }}
    tailscale.com/tags: tag:k8s
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  ports:
    - name: https
      port: 443
      targetPort: {{ $service.backend.port }}
      protocol: TCP
  selector:
    {{- toYaml $service.selector | nindent 4 }}
```
**Result:** Same optimistic lock error + auth failure.

### 3. tailscale.com/expose annotation on ClusterIP service
**File:** `helm-values/core/teleport-cluster.yaml`
```yaml
service:
  type: ClusterIP
annotations:
  service:
    tailscale.com/expose: "true"
    tailscale.com/hostname: teleport
    tailscale.com/tags: tag:k8s
```
**Result:** Annotations applied to ALL services (proxy + auth), creating two Tailscale devices.

### 4. ArgoCD ignoreDifferences + RespectIgnoreDifferences
**File:** `apps/templates/network/protected-services.yaml`
```yaml
spec:
  ignoreDifferences:
    - group: ""
      kind: Service
      name: teleport-ts-lb
      namespace: teleport
      jsonPointers:
        - /status
        - /metadata/finalizers
  syncPolicy:
    syncOptions:
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
```
**Result:** Still optimistic lock errors even with selfHeal disabled.

### 5. Disable selfHeal for protected-services
```bash
kubectl -n argocd patch application protected-services --type=json \
  -p='[{"op": "replace", "path": "/spec/syncPolicy/automated/selfHeal", "value": false}]'
```
**Result:** Pod still crashes - problem is NOT ArgoCD selfHeal.

## Root Cause Analysis

1. **Optimistic lock errors** - Known Tailscale operator issue [#14072](https://github.com/tailscale/tailscale/issues/14072). Multiple controllers updating same objects.

2. **Auth failure** - `machineAuthorized=false` means:
   - OAuth client may not have correct scopes (`devices:core`, `auth_keys`)
   - ACL may not auto-approve `tag:k8s` devices
   - `tag:k8s-operator` must be owner of `tag:k8s` in ACL

## Current Configuration

### Tailscale Operator
- Version: v1.90.9
- Helm values: `helm-values/network/tailscale-operator.yaml`
```yaml
operatorConfig:
  defaultTags:
    - "tag:k8s-operator"
proxyConfig:
  defaultTags: "tag:k8s"
```

### ACL Requirements (Tailscale Admin Console)
```json
{
  "tagOwners": {
    "tag:k8s-operator": ["autogroup:admin"],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "autoApprovers": {
    "tag:k8s": {}
  }
}
```

### OAuth Client Requirements
- Scopes: `devices:core:write`, `auth_keys:write`
- Tags: `tag:k8s-operator`

## Files Modified

1. `charts/protected-services/templates/tailscale-direct.yaml` - New template for direct Tailscale LB
2. `charts/protected-services/templates/ingresses.yaml` - Exclude `direct: true` services
3. `charts/protected-services/templates/tailscale-services.yaml` - Exclude `direct: true` services
4. `charts/protected-services/values.yaml` - Added teleport with `direct: true`
5. `apps/templates/network/protected-services.yaml` - Added ignoreDifferences
6. `apps/templates/core/teleport.yaml` - ArgoCD Application
7. `helm-values/core/teleport-cluster.yaml` - Teleport Helm values
8. `charts/argocd-config/templates/projects.yaml` - Added teleport namespace to infrastructure and network projects

## Next Steps

1. **Check Tailscale ACL** - Ensure `tag:k8s` devices are auto-approved
2. **Check OAuth client scopes** - Must have `devices:core:write` and `auth_keys:write`
3. **Alternative: Use Tailscale Ingress with ProxyGroup** - But this doesn't support TCP passthrough
4. **Alternative: Manual Tailscale sidecar** - Deploy tailscale container alongside Teleport

## References

- [Tailscale Kubernetes Operator Docs](https://tailscale.com/kb/1236/kubernetes-operator)
- [Tailscale Cluster Ingress](https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress)
- [Tailscale Operator Troubleshooting](https://tailscale.com/kb/1446/kubernetes-operator-troubleshooting)
- [GitHub Issue #14072 - Optimistic Lock](https://github.com/tailscale/tailscale/issues/14072)
- [ArgoCD Diffing](https://argo-cd.readthedocs.io/en/stable/user-guide/diffing/)
- [ArgoCD Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Teleport Helm Reference](https://goteleport.com/docs/reference/helm-reference/teleport-cluster/)
