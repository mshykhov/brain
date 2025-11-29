# kubectl Setup

Установка kubectl на Linux (Ubuntu/Debian).

## Установка через apt

```bash
# Зависимости
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# Ключ репозитория
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Добавить репозиторий
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

# Установить
sudo apt-get update
sudo apt-get install -y kubectl
```

## Проверка

```bash
kubectl version --client
```

## Автодополнение (bash)

```bash
sudo apt-get install -y bash-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc
```

## Ссылки

- [Официальная документация](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
