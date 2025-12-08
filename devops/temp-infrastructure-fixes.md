# Infrastructure Fixes TODO

## In Progress
- [ ] ArgoCD projects - replace hardcoded `example-*` with `{{ .Values.global.servicePrefix }}-*`
  - Files: `charts/argocd-config/templates/projects.yaml`
  - Need: add `servicePrefix` to values.yaml and pass via valuesObject

## Completed
- [x] doppler-prd.yaml - fix comment "dev environment" → "prd environment"

## Pending
- [ ] oauth2-proxy-endpoint.yaml - not updated for `subdomain` pattern
  - File: `charts/protected-services/templates/oauth2-proxy-endpoint.yaml`
  - Issue: Uses old `$service.hostname` instead of new `subdomain` pattern from ingresses.yaml
  - Need: Sync logic with ingresses.yaml

- [ ] README placeholders table - add `<SERVICE_PREFIX>` after implementation

## Notes
- `charts/credentials/values.yaml` - NOT needed (uses valuesObject from Application)
- `charts/redis-instance/templates/_helpers.tpl` - NEEDED (used by all templates)
