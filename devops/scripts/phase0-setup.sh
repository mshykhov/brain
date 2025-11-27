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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Spinner characters
SPINNER_CHARS='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BOLD}${CYAN}>>> $1${NC}"; }

# Spinner for long-running operations
# Usage: run_with_spinner "message" command args...
run_with_spinner() {
    local msg="$1"
    shift
    local pid
    local i=0

    # Start command in background
    "$@" &>/dev/null &
    pid=$!

    # Show spinner while command runs
    printf "${BLUE}[....]${NC} %s " "$msg"
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${BLUE}[${SPINNER_CHARS:i++%${#SPINNER_CHARS}:1}]${NC} %s " "$msg"
        sleep 0.1
    done

    # Check exit status
    if wait "$pid"; then
        printf "\r${GREEN}[OK]${NC} %s\n" "$msg"
        return 0
    else
        printf "\r${RED}[FAIL]${NC} %s\n" "$msg"
        return 1
    fi
}

# Progress bar for waiting operations
# Usage: wait_with_progress "message" seconds
wait_with_progress() {
    local msg="$1"
    local total="$2"
    local elapsed=0
    local width=30

    while [[ $elapsed -lt $total ]]; do
        local progress=$((elapsed * width / total))
        local remaining=$((width - progress))
        local bar=$(printf "%${progress}s" | tr ' ' '█')
        local empty=$(printf "%${remaining}s" | tr ' ' '░')
        printf "\r${BLUE}[INFO]${NC} %s [%s%s] %ds/%ds " "$msg" "$bar" "$empty" "$elapsed" "$total"
        sleep 1
        ((elapsed++))
    done
    printf "\r${GREEN}[OK]${NC} %s [$(printf "%${width}s" | tr ' ' '█')] %ds    \n" "$msg" "$total"
}

# Waiting spinner with timeout check
# Usage: wait_for_condition "message" "condition_command" max_seconds
wait_for_condition() {
    local msg="$1"
    local condition="$2"
    local max_seconds="$3"
    local elapsed=0
    local i=0

    printf "${BLUE}[....]${NC} %s (timeout: %ds) " "$msg" "$max_seconds"

    while [[ $elapsed -lt $max_seconds ]]; do
        if eval "$condition" &>/dev/null; then
            printf "\r${GREEN}[OK]${NC} %s (%ds)                    \n" "$msg" "$elapsed"
            return 0
        fi
        printf "\r${BLUE}[${SPINNER_CHARS:i++%${#SPINNER_CHARS}:1}]${NC} %s (%ds/%ds) " "$msg" "$elapsed" "$max_seconds"
        sleep 1
        ((elapsed++))
    done

    printf "\r${RED}[FAIL]${NC} %s (timeout after %ds)\n" "$msg" "$max_seconds"
    return 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check system requirements
check_system() {
    log_step "Step 1/7: Checking system requirements"

    # Check if Debian-based
    if ! command -v apt-get &> /dev/null; then
        log_error "This script requires apt-get (Debian/Ubuntu)"
        exit 1
    fi
    log_success "Debian-based system detected"

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
    log_step "Step 2/7: Installing base dependencies"

    log_info "Updating package lists..."
    apt-get update -qq

    local packages=(curl wget apt-transport-https ca-certificates gnupg lsb-release jq)
    local total=${#packages[@]}
    local current=0

    for pkg in "${packages[@]}"; do
        ((current++))
        if dpkg -l "$pkg" &>/dev/null; then
            printf "${GREEN}[OK]${NC} [%d/%d] %s (already installed)\n" "$current" "$total" "$pkg"
        else
            printf "${BLUE}[....]${NC} [%d/%d] Installing %s... " "$current" "$total" "$pkg"
            if apt-get install -y -qq "$pkg" &>/dev/null; then
                printf "\r${GREEN}[OK]${NC} [%d/%d] %s installed            \n" "$current" "$total" "$pkg"
            else
                printf "\r${RED}[FAIL]${NC} [%d/%d] %s failed            \n" "$current" "$total" "$pkg"
                exit 1
            fi
        fi
    done

    log_success "All dependencies installed"
}

# Install k3s
# Docs: https://docs.k3s.io/installation/configuration
install_k3s() {
    log_step "Step 3/7: Installing k3s"

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

    log_info "Configuration:"
    echo "  --disable=traefik      (will use custom ingress controller)"
    echo "  --disable=servicelb    (will use MetalLB)"
    echo "  --write-kubeconfig-mode=644"

    # Download and install k3s
    log_info "Downloading k3s installation script..."
    local tmp_script
    tmp_script=$(mktemp)

    if ! curl -sfL https://get.k3s.io -o "$tmp_script"; then
        log_error "Failed to download k3s installation script"
        rm -f "$tmp_script"
        exit 1
    fi
    log_success "Installation script downloaded"

    log_info "Installing k3s (this may take 1-2 minutes)..."
    # Run installation with visible output for progress
    INSTALL_K3S_EXEC="server --disable=traefik --disable=servicelb --write-kubeconfig-mode=644" \
        bash "$tmp_script"
    rm -f "$tmp_script"

    # Wait for k3s to be ready
    if ! wait_for_condition "Waiting for k3s to be ready" "k3s kubectl get nodes" 60; then
        log_error "k3s failed to start within timeout"
        log_info "Checking logs..."
        journalctl -u k3s --no-pager -n 30
        exit 1
    fi

    log_success "k3s installed and running"
    k3s --version | head -1
}

# Setup kubectl configuration
setup_kubectl() {
    log_step "Step 4/7: Setting up kubectl"

    # Determine user home directory
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)
    local kube_dir="$user_home/.kube"

    # Create .kube directory
    mkdir -p "$kube_dir"
    log_success "Created $kube_dir"

    # Copy kubeconfig
    cp /etc/rancher/k3s/k3s.yaml "$kube_dir/config"
    log_success "Copied kubeconfig"

    # Set permissions
    chown -R "$real_user:$real_user" "$kube_dir"
    chmod 600 "$kube_dir/config"
    log_success "Set permissions (600)"

    # Create kubectl symlink if not exists
    if ! command -v kubectl &> /dev/null; then
        ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl 2>/dev/null || true
        log_success "Created kubectl symlink"
    else
        log_info "kubectl already exists"
    fi

    # Add KUBECONFIG to .bashrc if not present
    local bashrc="$user_home/.bashrc"
    if ! grep -q "KUBECONFIG=" "$bashrc" 2>/dev/null; then
        {
            echo ""
            echo "# Kubernetes configuration"
            echo "export KUBECONFIG=$kube_dir/config"
        } >> "$bashrc"
        log_success "Added KUBECONFIG to .bashrc"
    fi

    # Add kubectl completion if not present
    if ! grep -q "kubectl completion" "$bashrc" 2>/dev/null; then
        {
            echo 'source <(kubectl completion bash)'
            echo 'alias k=kubectl'
            echo 'complete -o default -F __start_kubectl k'
        } >> "$bashrc"
        log_success "Added kubectl completion and alias 'k'"
    fi

    log_success "kubectl configured for user: $real_user"
}

# Install Helm
# Docs: https://helm.sh/docs/intro/install/
install_helm() {
    log_step "Step 5/7: Installing Helm"

    if command -v helm &> /dev/null; then
        log_warn "Helm is already installed"
        helm version --short
        return 0
    fi

    log_info "Downloading Helm installation script..."
    local tmp_script
    tmp_script=$(mktemp)

    if ! curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmp_script"; then
        log_error "Failed to download Helm installation script"
        rm -f "$tmp_script"
        exit 1
    fi
    log_success "Installation script downloaded"

    log_info "Installing Helm..."
    bash "$tmp_script"
    rm -f "$tmp_script"

    # Add completion to bashrc
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)
    local bashrc="$user_home/.bashrc"

    if ! grep -q "helm completion" "$bashrc" 2>/dev/null; then
        echo 'source <(helm completion bash)' >> "$bashrc"
        log_success "Added helm completion to .bashrc"
    fi

    log_success "Helm installed: $(helm version --short)"
}

# Install k9s
# Docs: https://k9scli.io/topics/install/
install_k9s() {
    log_step "Step 6/7: Installing k9s"

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
    log_info "Detected architecture: $arch"

    # Get latest version from GitHub API
    log_info "Fetching latest k9s version..."
    local latest_version
    latest_version=$(curl -sL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')

    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        log_error "Failed to get k9s version from GitHub"
        exit 1
    fi
    log_success "Latest version: $latest_version"

    local download_url="https://github.com/derailed/k9s/releases/download/${latest_version}/k9s_Linux_${arch}.tar.gz"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Download with progress
    log_info "Downloading k9s ${latest_version}..."
    if ! curl -L --progress-bar "$download_url" -o "$tmp_dir/k9s.tar.gz"; then
        log_error "Failed to download k9s"
        rm -rf "$tmp_dir"
        exit 1
    fi

    log_info "Extracting..."
    if ! tar xzf "$tmp_dir/k9s.tar.gz" -C "$tmp_dir" k9s; then
        log_error "Failed to extract k9s"
        rm -rf "$tmp_dir"
        exit 1
    fi

    mv "$tmp_dir/k9s" /usr/local/bin/k9s
    chmod +x /usr/local/bin/k9s
    rm -rf "$tmp_dir"

    log_success "k9s installed: $(k9s version --short 2>/dev/null || k9s version | head -1)"
}

# Verify installation
verify_installation() {
    log_step "Step 7/7: Verifying installation"

    echo ""
    echo "┌──────────────────────────────────────────┐"
    echo "│         Installed Components             │"
    echo "├──────────────────────────────────────────┤"

    # k3s
    printf "│ k3s:     "
    local k3s_ver
    k3s_ver=$(k3s --version 2>/dev/null | head -1 | awk '{print $3}') || k3s_ver="NOT INSTALLED"
    printf "%-30s │\n" "$k3s_ver"

    # kubectl
    printf "│ kubectl: "
    local kubectl_ver
    kubectl_ver=$(kubectl version --client 2>/dev/null | grep -oP 'v\d+\.\d+\.\d+' | head -1) || kubectl_ver="NOT INSTALLED"
    printf "%-30s │\n" "$kubectl_ver"

    # helm
    printf "│ helm:    "
    local helm_ver
    helm_ver=$(helm version --short 2>/dev/null) || helm_ver="NOT INSTALLED"
    printf "%-30s │\n" "$helm_ver"

    # k9s
    printf "│ k9s:     "
    local k9s_ver
    k9s_ver=$(k9s version --short 2>/dev/null) || k9s_ver="NOT INSTALLED"
    printf "%-30s │\n" "$k9s_ver"

    echo "└──────────────────────────────────────────┘"
    echo ""

    # Cluster status
    echo "Cluster status:"
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
    echo "Pods in kube-system:"
    kubectl get pods -n kube-system
}

# Print post-installation info
print_info() {
    local real_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$real_user" | cut -d: -f6)

    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║       INSTALLATION COMPLETE              ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Reload shell or run:"
    echo "     ${CYAN}source ~/.bashrc${NC}"
    echo ""
    echo "  2. Verify cluster:"
    echo "     ${CYAN}kubectl get nodes${NC}"
    echo "     ${CYAN}kubectl get pods -A${NC}"
    echo ""
    echo "  3. Launch k9s for visual management:"
    echo "     ${CYAN}k9s${NC}"
    echo ""
    echo "  4. KUBECONFIG location:"
    echo "     ${CYAN}$user_home/.kube/config${NC}"
    echo ""
    echo "┌──────────────────────────────────────────┐"
    echo "│  Phase 1 (Core) - Next to install:      │"
    echo "│    • MetalLB (LoadBalancer)              │"
    echo "│    • Longhorn (Storage)                  │"
    echo "│    • ArgoCD (GitOps)                     │"
    echo "└──────────────────────────────────────────┘"
    echo ""
}

# Main entry point
main() {
    echo ""
    echo "╔══════════════════════════════════════════╗"
    echo "║     K3s + Tools Setup - Phase 0         ║"
    echo "║     Target: Ubuntu 22.04+ / Debian      ║"
    echo "╚══════════════════════════════════════════╝"
    echo ""

    local start_time=$SECONDS

    check_root
    check_system
    install_deps
    install_k3s
    setup_kubectl
    install_helm
    install_k9s
    verify_installation
    print_info

    local elapsed=$((SECONDS - start_time))
    echo "Total time: ${elapsed}s"
    echo ""
}

main "$@"
