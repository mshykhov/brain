# MetalLB Setup

LoadBalancer для bare-metal Kubernetes.

**Docs:** https://metallb.io/installation/

## Установка

```bash
# 1. Применить манифест (v0.14.9)
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# 2. Дождаться готовности
kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=120s

# 3. Проверить
kubectl get pods -n metallb-system
```

## Конфигурация IPAddressPool

```bash
# Применить конфиг (заменить IP на свою подсеть)
kubectl apply -f - <<'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.8.240-192.168.8.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default-pool
EOF
```

## Проверка

```bash
# Создать тестовый сервис
kubectl create deployment nginx-test --image=nginx
kubectl expose deployment nginx-test --port=80 --type=LoadBalancer

# Проверить что IP назначился
kubectl get svc nginx-test

# Тест
curl http://192.168.8.240

# Удалить тест
kubectl delete deployment nginx-test
kubectl delete svc nginx-test
```

## Timeline

| Дата | Действие |
|------|----------|
| 2024-11-27 | Установка v0.14.9, IPAddressPool 192.168.8.240-250 |
