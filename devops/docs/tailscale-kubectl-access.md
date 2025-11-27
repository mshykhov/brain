# Доступ к kubectl через Tailscale

**Docs:** https://tailscale.com/kb/1185/kubernetes

## Простой способ (без Operator)

Tailscale на сервере + Tailscale на локальной машине = прямой доступ по tailnet IP.

### 1. Сервер (где k3s)

```bash
curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/tailscale-server-setup.sh | sudo bash
```

Запомни Tailscale IP сервера (например `100.x.x.x`).

### 2. Локальная машина (Windows/WSL)

**Windows:**
- Скачать: https://tailscale.com/download/windows
- Установить, залогиниться

**WSL (если нужен kubectl из WSL):**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 3. Копирование kubeconfig

```bash
# С сервера (замени IP на свой tailscale IP)
SERVER_IP="100.x.x.x"

# Скопировать kubeconfig
scp $SERVER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config-tailscale

# Заменить localhost на tailscale IP
sed -i "s/127.0.0.1/$SERVER_IP/g" ~/.kube/config-tailscale

# Использовать
export KUBECONFIG=~/.kube/config-tailscale
kubectl get nodes
```

### 4. Постоянная настройка

```bash
# Добавить в ~/.bashrc или ~/.zshrc
export KUBECONFIG=~/.kube/config-tailscale
```

Или merge с основным kubeconfig:
```bash
# Backup
cp ~/.kube/config ~/.kube/config.backup

# Merge (если есть другие кластеры)
KUBECONFIG=~/.kube/config:~/.kube/config-tailscale kubectl config view --flatten > ~/.kube/config.merged
mv ~/.kube/config.merged ~/.kube/config
```

## Проверка

```bash
# Пинг по tailscale
ping 100.x.x.x

# kubectl
kubectl get nodes
kubectl get pods -A
```

## Troubleshooting

**Не пингуется:**
```bash
# Проверить статус
tailscale status

# Проверить что оба устройства в одном tailnet
tailscale status | grep online
```

**kubectl timeout:**
```bash
# Проверить что порт 6443 доступен
nc -zv 100.x.x.x 6443

# Проверить kubeconfig
kubectl config view
```

---

## Продвинутый способ: Kubernetes Operator

Для будущего (Фаза 4) — Tailscale Operator с API Server Proxy.

Преимущества:
- Автоматическая аутентификация через Tailscale identity
- RBAC на основе tailnet пользователей
- Ingress для сервисов через Tailscale

Docs: https://tailscale.com/kb/1236/kubernetes-operator
