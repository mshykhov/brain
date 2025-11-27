#!/bin/bash
# =============================================================================
# K3s + Tools Setup Script - Phase 0
# Installs k3s (without traefik, without servicelb) + kubectl + helm + k9s
# Target: Ubuntu 22.04+ / Debian-based systems
# Usage: sudo ./phase0-setup.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system requirements
check_system() {
    log_info "Checking system requirements..."

    # Check if Debian-based
    if ! command -v apt-get &> /dev/null; then
        log_error "This script requires apt-get (Debian/Ubuntu)"
        exit 1
    fi

    # Check resources
    local mem_total
    mem_total=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    local cpu_count
    cpu_count=$(nproc)

    log_info "CPU: ${cpu_count} cores, RAM: ${mem_total}GB"

    if [[ $mem_total -lt 4 ]]; then
        log_warn "Minimum 4GB RAM recommended (current: ${mem_total}GB)"
    fi

    if [[ $cpu_count -lt 2 ]]; then
        log_warn "Minimum 2 CPUs recommended (current: ${cpu_count})"
    fi

    log_success "System check completed"
}

# Install base dependencies
install_deps() {
    log_info "Installing base dependencies..."

    apt-get update -qq
    apt-get install -y -qq \
        curl \
        wget \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq

    log_success "Dependencies installed"
}

# Install k3s
# Docs: https://docs.k3s.io/installation/configuration
install_k3s() {
    log_info "Installing k3s (without traefik, without servicelb)..."

    # Check for existing installation
    if command -v k3s &> /dev/null; then
        log_warn "k3s is already installed"
        k3s --version
        read -r -p "Reinstall? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            log_info "Skipping k3s installation"
            return 0
        fi
        log_info "Removing existing k3s..."
        /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true
    fi

    # Install k3s with disabled components
    # --disable traefik: do not install built-in Traefik ingress controller
    # --disable servicelb: do not install built-in LoadBalancer (Klipper)
    # --write-kubeconfig-mode 644: allow kubeconfig access without sudo
    # Docs: https://docs.k3s.io/cli/server
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
        --disable=traefik \
        --disable=servicelb \
        --write-kubeconfig-mode=644" sh -

    # Wait for k3s to start
    log_info "Waiting for k3s to start..."
    sleep 10

    # Check status with timeout
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
        log_error "k3s failed to start within timeout"
        journalctl -u k3s --no-pager -n 50
        exit 1
    fi

    log_success "k3s installed and running"
    k3s --version
}

# Setup kubectl configuration
setup_kubectl() {
    log_info "Setting up kubectl..."

    # Determine user home directory
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)
    local kube_dir="$user_home/.kube"

    # Create .kube directory
    mkdir -p "$kube_dir"

    # Copy kubeconfig
    cp /etc/rancher/k3s/k3s.yaml "$kube_dir/config"

    # Set permissions
    chown -R "$real_user:$real_user" "$kube_dir"
    chmod 600 "$kube_dir/config"

    # Create kubectl symlink if not exists
    if ! command -v kubectl &> /dev/null; then
        ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
    fi

    # Add KUBECONFIG to .bashrc if not present
    local bashrc="$user_home/.bashrc"
    if ! grep -q "KUBECONFIG=" "$bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# Kubernetes configuration"
            echo "export KUBECONFIG=$kube_dir/config"
        } >> "$bashrc"
    fi

    # Add kubectl completion if not present
    if ! grep -q "kubectl completion" "$bashrc" 2>/dev/null; then
        {
            echo 'source <(kubectl completion bash)'
            echo 'alias k=kubectl'
            echo 'complete -o default -F __start_kubectl k'
        } >> "$bashrc"
    fi

    log_success "kubectl configured"
}

# Install Helm
# Docs: https://helm.sh/docs/intro/install/
install_helm() {
    log_info "Installing Helm..."

    if command -v helm &> /dev/null; then
        log_warn "Helm is already installed"
        helm version --short
        return 0
    fi

    # Official Helm installation script
    # Source: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

    # Add completion to bashrc
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)
    local bashrc="$user_home/.bashrc"

    if ! grep -q "helm completion" "$bashrc" 2>/dev/null; then
        echo 'source <(helm completion bash)' >> "$bashrc"
    fi

    log_success "Helm installed"
    helm version --short
}

# Install k9s
# Docs: https://k9scli.io/topics/install/
install_k9s() {
    log_info "Installing k9s..."

    if command -v k9s &> /dev/null; then
        log_warn "k9s is already installed"
        k9s version --short 2>/dev/null || k9s version
        return 0
    fi

    # Detect architecture
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="arm" ;;
        *) log_error "Unsupported architecture: $arch"; exit 1 ;;
    esac

    # Get latest version from GitHub API
    local latest_version
    latest_version=$(curl -sL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')

    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        log_error "Failed to get k9s version from GitHub"
        exit 1
    fi

    log_info "Downloading k9s ${latest_version}..."

    local download_url="https://github.com/derailed/k9s/releases/download/${latest_version}/k9s_Linux_${arch}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Download and extract
    if ! curl -sL "$download_url" -o "$tmp_dir/k9s.tar.gz"; then
        log_error "Failed to download k9s"
        rm -rf "$tmp_dir"
        exit 1
    fi

    if ! tar xzf "$tmp_dir/k9s.tar.gz" -C "$tmp_dir" k9s; then
        log_error "Failed to extract k9s"
        rm -rf "$tmp_dir"
        exit 1
    fi

    mv "$tmp_dir/k9s" /usr/local/bin/k9s
    chmod +x /usr/local/bin/k9s
    rm -rf "$tmp_dir"

    log_success "k9s installed"
    k9s version --short 2>/dev/null || k9s version
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Installed components:${NC}"
    echo "=========================================="

    # k3s
    echo -n "k3s: "
    k3s --version 2>/dev/null | head -1 || echo "NOT INSTALLED"

    # kubectl
    echo -n "kubectl: "
    kubectl version --client 2>/dev/null | grep -oP 'Client Version: \K[^\s]+' || \
    kubectl version --client 2>/dev/null | head -1 || echo "NOT INSTALLED"

    # helm
    echo -n "helm: "
    helm version --short 2>/dev/null || echo "NOT INSTALLED"

    # k9s
    echo -n "k9s: "
    k9s version --short 2>/dev/null || echo "NOT INSTALLED"

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Cluster status:${NC}"
    echo "=========================================="

    # Nodes
    kubectl get nodes -o wide 2>/dev/null || log_warn "Failed to get nodes"

    echo ""

    # Verify disabled components
    echo "Disabled components check:"
    if kubectl get deploy -n kube-system traefik &>/dev/null; then
        log_warn "Traefik is STILL installed (possibly from previous installation)"
    else
        log_success "Traefik is disabled"
    fi

    if kubectl get ds -n kube-system -l svccontroller.k3s.cattle.io/svcname &>/dev/null 2>&1; then
        log_warn "ServiceLB is STILL installed"
    else
        log_success "ServiceLB is disabled"
    fi

    echo ""
    echo "=========================================="
    echo -e "${GREEN}Pods in kube-system:${NC}"
    echo "=========================================="
    kubectl get pods -n kube-system
}

# Print post-installation info
print_info() {
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)

    echo ""
    echo "=========================================="
    echo -e "${GREEN}INSTALLATION COMPLETE${NC}"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Reload shell or run:"
    echo "   source ~/.bashrc"
    echo ""
    echo "2. Verify cluster:"
    echo "   kubectl get nodes"
    echo "   kubectl get pods -A"
    echo ""
    echo "3. Launch k9s for visual management:"
    echo "   k9s"
    echo ""
    echo "4. KUBECONFIG location:"
    echo "   $user_home/.kube/config"
    echo ""
    echo "Phase 1 (Core) components to install:"
    echo "  - MetalLB (LoadBalancer)"
    echo "  - Longhorn (Storage)"
    echo "  - ArgoCD (GitOps)"
    echo ""
}

# Main entry point
main() {
    echo ""
    echo "=========================================="
    echo "  K3s + Tools Setup - Phase 0"
    echo "  Target: Ubuntu 22.04+ / Debian"
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
