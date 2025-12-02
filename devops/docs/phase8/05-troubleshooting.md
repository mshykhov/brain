# Troubleshooting

## Common Issues

### Grafana не доступен

1. Проверь pods:
```bash
kubectl get pods -n monitoring
```

2. Проверь protected-services:
```bash
kubectl get ingress -n monitoring
kubectl get svc -n monitoring
```

3. Проверь oauth2-proxy logs:
```bash
kubectl logs -n oauth2-proxy -l app.kubernetes.io/name=oauth2-proxy
```

### Prometheus не собирает метрики

1. Проверь ServiceMonitor:
```bash
kubectl get servicemonitor -A
```

2. Проверь что `serviceMonitorSelectorNilUsesHelmValues: false`:
```bash
kubectl get prometheus -n monitoring -o yaml | grep -A5 serviceMonitor
```

3. Проверь targets в Prometheus:
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets
```

### Loki не получает логи

1. Проверь Alloy pods:
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy
```

2. Проверь Loki endpoint:
```bash
kubectl port-forward -n monitoring svc/loki 3100:3100
curl http://localhost:3100/ready
```

3. Проверь LogQL в Grafana:
```
{namespace="example-api-dev"}
```

### PVC не создаётся

1. Проверь StorageClass:
```bash
kubectl get sc
```

2. Проверь PVC status:
```bash
kubectl get pvc -n monitoring
```

3. Проверь Longhorn:
```bash
kubectl get pods -n longhorn-system
```

## Useful Commands

### Prometheus

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Check Prometheus config
kubectl get secret -n monitoring prometheus-kube-prometheus-stack-prometheus -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip
```

### Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Default credentials (if not using oauth2-proxy)
# admin / prom-operator
```

### Loki

```bash
# Port-forward Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Check ready
curl http://localhost:3100/ready

# Query logs
curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="example-api-dev"}' | jq
```

### Alloy

```bash
# Check Alloy config
kubectl get cm -n monitoring alloy -o yaml

# Check Alloy logs
kubectl logs -n monitoring -l app.kubernetes.io/name=alloy -f
```

## Log Queries (LogQL)

```logql
# All logs from namespace
{namespace="example-api-dev"}

# Filter by container
{namespace="example-api-dev", container="example-api-dev"}

# Search text
{namespace="example-api-dev"} |= "error"

# Regex
{namespace="example-api-dev"} |~ "(?i)exception"

# JSON parsing
{namespace="example-api-dev"} | json | level="ERROR"
```

## Metric Queries (PromQL)

```promql
# HTTP request rate
rate(http_server_requests_seconds_count[5m])

# JVM memory
jvm_memory_used_bytes{area="heap"}

# Container CPU
rate(container_cpu_usage_seconds_total[5m])

# Pod restarts
kube_pod_container_status_restarts_total
```
