# Infrastructure Fixes TODO

## 1. doppler-prd.yaml - DONE
- [x] Fix comment "dev environment" → "prd environment"
- File: `manifests/core/cluster-secret-stores/doppler-prd.yaml`

## 2. ArgoCD projects hardcoded namespaces - IN PROGRESS
- [ ] Replace hardcoded `example-*` with `{{ .Values.global.servicePrefix }}-*`
- File: `charts/argocd-config/templates/projects.yaml` (lines 70, 117, 175, 192)
- Need: add `servicePrefix` to values.yaml and pass via valuesObject

## 3. charts/credentials - no values.yaml - NOT AN ISSUE
- Chart uses valuesObject from Application (passes global.* values)
- This is correct pattern - no fix needed

## 4. oauth2-proxy-endpoint.yaml - TODO
- [ ] Not updated for `subdomain` pattern
- File: `charts/protected-services/templates/oauth2-proxy-endpoint.yaml`
- Issue: Uses old `$service.hostname` instead of new `subdomain` pattern
- Need: Sync logic with `ingresses.yaml`

## 5. redis-instance/_helpers.tpl - NOT AN ISSUE
- File exists and is NEEDED (used by all templates)
- Contains: fullname, labels, secretName helpers
- No fix needed
