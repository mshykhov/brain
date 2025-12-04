# Testing & Verification

## Step 1: Test Telegram Bot Directly

Before configuring Alertmanager, verify bot works:

```bash
BOT_TOKEN="your_token_here"
CHAT_ID="-1001234567890"
TOPIC_ID="2"

curl -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{
    \"chat_id\": ${CHAT_ID},
    \"message_thread_id\": ${TOPIC_ID},
    \"text\": \"🧪 Test message from curl\",
    \"parse_mode\": \"HTML\"
  }"
```

Expected: `{"ok":true,...}`

## Step 2: Verify Watchdog Alert

Watchdog is always firing - proves alerting works:

```bash
# Check Watchdog is firing
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname=="Watchdog")'

# Should show state: "firing"
```

After configuring Alertmanager, Watchdog should appear in Info topic every 24h.

## Step 3: Trigger Test Alert

Create a test PrometheusRule:

```yaml
# test-alert.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-alert
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: test
      rules:
        - alert: TestAlertCritical
          expr: vector(1)
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Test critical alert"
            description: "This is a test critical alert"

        - alert: TestAlertWarning
          expr: vector(1)
          for: 1m
          labels:
            severity: warning
          annotations:
            summary: "Test warning alert"
```

Apply and wait:

```bash
kubectl apply -f test-alert.yaml

# Wait 1-2 minutes for alert to fire
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alertname | startswith("TestAlert"))'

# Delete after testing
kubectl delete -f test-alert.yaml
```

## Step 4: Check Alertmanager Status

```bash
# Port forward to Alertmanager UI
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Open http://localhost:9093
```

**Check:**
- Status → Config (verify telegram receivers)
- Alerts → see firing alerts
- Silences → verify none blocking

## Step 5: Check Alertmanager Logs

```bash
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0 | grep -i telegram
```

Look for:
- `msg="Notify success"` - notification sent
- `msg="Notify attempt failed"` - check error

## Step 6: Verify Topic Routing

After test alerts fire, check Telegram:

| Alert | Expected Topic |
|-------|----------------|
| TestAlertCritical | 🔴 Critical |
| TestAlertWarning | 🟠 Warning |
| Watchdog | ⚪ Info |

## Step 7: Test Inhibition

Create alerts that should inhibit:

```yaml
# test-inhibit.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: test-inhibit
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: test-inhibit
      rules:
        - alert: TestInhibitCritical
          expr: vector(1)
          for: 1m
          labels:
            severity: critical
            alertname: TestInhibit
          annotations:
            summary: "Critical version"

        - alert: TestInhibitWarning
          expr: vector(1)
          for: 1m
          labels:
            severity: warning
            alertname: TestInhibit
          annotations:
            summary: "Warning version (should be inhibited)"
```

Expected: Only Critical notification, Warning inhibited.

Check inhibited alerts:
```bash
# In Alertmanager UI → Alerts → check "Inhibited" checkbox
```

## Step 8: Test Resolved Notifications

1. Create test alert (from Step 3)
2. Wait for notification in Telegram
3. Delete PrometheusRule
4. Wait ~5 minutes
5. Should see ✅ RESOLVED notification

## Step 9: Test ArgoCD Notifications

```bash
# Trigger sync on an app
argocd app sync example-api-dev --prune

# Check notification in Deploys topic

# Check ArgoCD notification logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-notifications-controller --tail=50
```

## Troubleshooting Checklist

### No notifications arriving

- [ ] Bot token correct in secret?
- [ ] Chat ID negative for groups?
- [ ] Topic IDs correct?
- [ ] Bot is admin in group?
- [ ] Secret mounted in Alertmanager?
- [ ] Alertmanager config applied?

### Wrong topic receiving alerts

- [ ] Check message_thread_id in config
- [ ] Verify routing matchers match alert labels
- [ ] Check for typos in severity labels

### Duplicate notifications

- [ ] Check `continue: false` on routes
- [ ] Verify group_interval not too short

### Missing resolved notifications

- [ ] Check `send_resolved: true` in receiver
- [ ] Alert must be firing before it can resolve
- [ ] Check resolve_timeout in global config

## Verification Commands Reference

```bash
# Prometheus alerts
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | jq

# Alertmanager config
kubectl get secret -n monitoring alertmanager-kube-prometheus-stack-alertmanager \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Alertmanager alerts
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
# curl http://localhost:9093/api/v2/alerts

# Telegram secret
kubectl get secret -n monitoring telegram-secrets -o yaml

# ArgoCD notification config
kubectl get configmap -n argocd argocd-notifications-cm -o yaml
```

## Success Criteria

✅ Watchdog alert appears in Info topic (every 24h)
✅ Test critical alert appears in Critical topic
✅ Test warning alert appears in Warning topic
✅ Warning suppressed when Critical fires for same alertname
✅ Resolved notifications arrive when alerts clear
✅ ArgoCD deploy notifications in Deploys topic
