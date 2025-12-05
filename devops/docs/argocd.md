# ArgoCD Commands

Команды для работы с ArgoCD.

## Установка CLI

```bash
brew install argocd
```

Или:

```bash
VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

## Login

```bash
# Core mode (через kubectl, без API server)
kubectl config set-context --current --namespace=argocd
argocd login --core

# Через server
argocd login argocd.example.com --grpc-web

# С паролем
argocd login argocd.example.com --username admin --password <password>
```

## Applications

```bash
# Список всех apps
argocd app list

# По project
argocd app list -p monitoring
argocd app list -p data

# Только имена
argocd app list -o name
argocd app list -p monitoring -o name

# Детали app
argocd app get <app-name>

# Sync
argocd app sync <app-name>

# Hard refresh
argocd app get <app-name> --hard-refresh

# Delete app
argocd app delete <app-name> -y

# Delete все apps в project
argocd app list -p monitoring -o name | xargs argocd app delete -y --wait
```

## Projects

```bash
# Список projects
argocd proj list

# Детали project
argocd proj get <project-name>
```

## Sync

```bash
# Sync app
argocd app sync <app-name>

# Sync с prune
argocd app sync <app-name> --prune

# Force sync
argocd app sync <app-name> --force

# Sync all apps in project
argocd app list -p monitoring -o name | xargs -I {} argocd app sync {}
```

## Rollback

```bash
# История deployments
argocd app history <app-name>

# Rollback к revision
argocd app rollback <app-name> <revision>
```

## Troubleshooting

```bash
# Logs
argocd app logs <app-name>

# Resources
argocd app resources <app-name>

# Diff
argocd app diff <app-name>

# Manifests
argocd app manifests <app-name>
```
