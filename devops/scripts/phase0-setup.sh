#!/bin/bash
# =============================================================================
# K3s + Tools Setup Script - Phase 0
# Установка k3s (без traefik, без servicelb) + kubectl + helm + k9s
# Ubuntu 22.04
# =============================================================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Проверка root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Скрипт должен запускаться от root (sudo)"
        exit 1
    fi
}

# Проверка системы
check_system() {
    log_info "Проверка системы..."

    # Проверка Ubuntu
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        log_warn "Не Ubuntu, но продолжаем..."
    fi

    # Проверка ресурсов
    local mem_total=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
    local cpu_count=$(nproc)

    log_info "CPU: ${cpu_count} cores, RAM: ${mem_total}GB"

    if [[ $mem_total -lt 4 ]]; then
        log_warn "Рекомендуется минимум 4GB RAM (сейчас ${mem_total}GB)"
    fi

    if [[ $cpu_count -lt 2 ]]; then
        log_warn "Рекомендуется минимум 2 CPU (сейчас ${cpu_count})"
    fi

    log_success "Проверка системы завершена"
}

# Установка зависимостей
install_deps() {
    log_info "Установка базовых зависимостей..."

    apt-get update -qq
    apt-get install -y -qq \
        curl \
        wget \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq

    log_success "Зависимости установлены"
}

# Установка k3s
install_k3s() {
    log_info "Установка k3s (без traefik, без servicelb)..."

    # Проверка существующей установки
    if command -v k3s &> /dev/null; then
        log_warn "k3s уже установлен"
        k3s --version
        read -p "Переустановить? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            log_info "Пропускаем установку k3s"
            return 0
        fi
        log_info "Удаляем старый k3s..."
        /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
    fi

    # Установка k3s с отключенными компонентами
    # --disable traefik: не устанавливать встроенный Traefik
    # --disable servicelb: не устанавливать встроенный LoadBalancer (Klipper)
    # --write-kubeconfig-mode 644: доступ к kubeconfig без sudo
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
        --disable=traefik \
        --disable=servicelb \
        --write-kubeconfig-mode=644" sh -

    # Ожидание запуска
    log_info "Ожидание запуска k3s..."
    sleep 10

    # Проверка статуса
    local max_attempts=30
    local attempt=0
    while [[ $attempt -lt $max_attempts ]]; do
        if k3s kubectl get nodes &>/dev/null; then
            break
        fi
        sleep 2
        ((attempt++))
    done

    if [[ $attempt -eq $max_attempts ]]; then
        log_error "k3s не запустился за отведённое время"
        journalctl -u k3s --no-pager -n 50
        exit 1
    fi

    log_success "k3s установлен и запущен"
    k3s --version
}

# Настройка kubectl
setup_kubectl() {
    log_info "Настройка kubectl..."

    local kube_dir="/home/${SUDO_USER:-$USER}/.kube"
    local user_home="/home/${SUDO_USER:-$USER}"

    # Создание .kube директории
    mkdir -p "$kube_dir"

    # Копирование kubeconfig
    cp /etc/rancher/k3s/k3s.yaml "$kube_dir/config"

    # Права доступа
    chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$kube_dir"
    chmod 600 "$kube_dir/config"

    # kubectl alias для удобства (если ещё нет)
    if ! command -v kubectl &> /dev/null; then
        ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
    fi

    # Добавление KUBECONFIG в .bashrc если ещё нет
    local bashrc="$user_home/.bashrc"
    if ! grep -q "KUBECONFIG" "$bashrc" 2>/dev/null; then
        echo "" >> "$bashrc"
        echo "# Kubernetes config" >> "$bashrc"
        echo "export KUBECONFIG=$kube_dir/config" >> "$bashrc"
    fi

    # Добавление kubectl completion
    if ! grep -q "kubectl completion" "$bashrc" 2>/dev/null; then
        echo 'source <(kubectl completion bash)' >> "$bashrc"
        echo 'alias k=kubectl' >> "$bashrc"
        echo 'complete -o default -F __start_kubectl k' >> "$bashrc"
    fi

    log_success "kubectl настроен"
}

# Установка Helm
install_helm() {
    log_info "Установка Helm..."

    if command -v helm &> /dev/null; then
        log_warn "Helm уже установлен"
        helm version --short
        return 0
    fi

    # Официальный способ установки Helm
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Добавление completion
    local bashrc="/home/${SUDO_USER:-$USER}/.bashrc"
    if ! grep -q "helm completion" "$bashrc" 2>/dev/null; then
        echo 'source <(helm completion bash)' >> "$bashrc"
    fi

    log_success "Helm установлен"
    helm version --short
}

# Установка k9s
install_k9s() {
    log_info "Установка k9s..."

    if command -v k9s &> /dev/null; then
        log_warn "k9s уже установлен"
        k9s version --short 2>/dev/null || k9s version
        return 0
    fi

    # Определение архитектуры
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) log_error "Неподдерживаемая архитектура: $arch"; exit 1 ;;
    esac

    # Получение последней версии
    local latest_version=$(curl -sL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')

    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        log_error "Не удалось получить версию k9s"
        exit 1
    fi

    log_info "Скачивание k9s ${latest_version}..."

    local download_url="https://github.com/derailed/k9s/releases/download/${latest_version}/k9s_Linux_${arch}.tar.gz"

    # Скачивание и установка
    curl -sL "$download_url" | tar xz -C /tmp k9s
    mv /tmp/k9s /usr/local/bin/k9s
    chmod +x /usr/local/bin/k9s

    log_success "k9s установлен"
    k9s version --short 2>/dev/null || k9s version
}

# Проверка установки
verify_installation() {
    log_info "Проверка установки..."

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Установленные компоненты:${NC}"
    echo "=========================================="

    # k3s
    echo -n "k3s: "
    k3s --version 2>/dev/null | head -1 || echo "НЕ УСТАНОВЛЕН"

    # kubectl
    echo -n "kubectl: "
    kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1 || echo "НЕ УСТАНОВЛЕН"

    # helm
    echo -n "helm: "
    helm version --short 2>/dev/null || echo "НЕ УСТАНОВЛЕН"

    # k9s
    echo -n "k9s: "
    k9s version --short 2>/dev/null || echo "НЕ УСТАНОВЛЕН"

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Статус кластера:${NC}"
    echo "=========================================="

    # Nodes
    kubectl get nodes -o wide 2>/dev/null || log_warn "Не удалось получить nodes"

    echo ""

    # Проверка что traefik и servicelb отключены
    echo "Проверка отключённых компонентов:"
    if kubectl get deploy -n kube-system traefik &>/dev/null; then
        log_warn "Traefik ВСЁ ЕЩЁ установлен (возможно старая установка)"
    else
        log_success "Traefik отключён"
    fi

    if kubectl get ds -n kube-system svclb-traefik &>/dev/null; then
        log_warn "ServiceLB ВСЁ ЕЩЁ установлен"
    else
        log_success "ServiceLB отключён"
    fi

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Pods в kube-system:${NC}"
    echo "=========================================="
    kubectl get pods -n kube-system
}

# Информация после установки
print_info() {
    local user_home="/home/${SUDO_USER:-$USER}"

    echo ""
    echo "=========================================="
    echo -e "${GREEN}УСТАНОВКА ЗАВЕРШЕНА${NC}"
    echo "=========================================="
    echo ""
    echo "Следующие шаги:"
    echo ""
    echo "1. Перелогиньтесь или выполните:"
    echo "   source ~/.bashrc"
    echo ""
    echo "2. Проверьте кластер:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
    echo "3. Запустите k9s для визуального управления:"
    echo "   k9s"
    echo ""
    echo "4. KUBECONFIG находится в:"
    echo "   $user_home/.kube/config"
    echo ""
    echo "Для Phase 1 (Core) нужно установить:"
    echo "  - MetalLB (LoadBalancer)"
    echo "  - Longhorn (Storage)"
    echo "  - ArgoCD (GitOps)"
    echo ""
}

# Main
main() {
    echo ""
    echo "=========================================="
    echo "  K3s + Tools Setup - Phase 0"
    echo "  Ubuntu 22.04"
    echo "=========================================="
    echo ""

    check_root
    check_system
    install_deps
    install_k3s
    setup_kubectl
    install_helm
    install_k9s
    verify_installation
    print_info
}

main "$@"
