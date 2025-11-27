#!/bin/bash
# Tailscale setup for k3s server
# Docs: https://tailscale.com/download/linux
# Run: curl -sL https://raw.githubusercontent.com/mshykhov/brain/main/devops/scripts/tailscale-server-setup.sh | sudo bash

set -e

echo "=== Installing Tailscale ==="

# Install Tailscale (official one-liner)
curl -fsSL https://tailscale.com/install.sh | sh

# Start and authenticate
echo ""
echo "=== Starting Tailscale ==="
echo "Follow the link below to authenticate:"
echo ""
sudo tailscale up

# Show IP
echo ""
echo "=== Done ==="
echo "Tailscale IP: $(tailscale ip -4)"
echo ""
echo "Next steps:"
echo "1. On your local machine, install Tailscale and run 'tailscale up'"
echo "2. Copy kubeconfig: scp $(tailscale ip -4):/etc/rancher/k3s/k3s.yaml ~/.kube/config-tailscale"
echo "3. Edit ~/.kube/config-tailscale: replace 127.0.0.1 with $(tailscale ip -4)"
echo "4. export KUBECONFIG=~/.kube/config-tailscale"
echo "5. kubectl get nodes"
