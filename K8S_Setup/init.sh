#!/bin/bash
set -e

# =========================
# Flags
# =========================
SKIP_DOCKER=false
SKIP_K8S=false

# =========================
# Usage
# =========================
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --skip-docker    Skip Docker installation"
    echo "  --skip-k8s       Skip Kubernetes installation"
    echo "  -h, --help       Show this help message"
    exit 0
}

# =========================
# Parse arguments
# =========================
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-docker) SKIP_DOCKER=true ;;
        --skip-k8s)    SKIP_K8S=true ;;
        -h|--help)     usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

# =========================
# Docker installation
# =========================
install_docker() {
    echo "Installing Docker..."

    sudo apt-get update
    sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc || true

    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        apt-transport-https

    sudo install -m 0755 -d /etc/apt/keyrings

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo ${UBUNTU_CODENAME}) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    sudo systemctl enable --now docker
}

# =========================
# Kubernetes installation (AUTO LATEST)
# =========================
install_k8s() {
    echo "Detecting latest Kubernetes version..."

    K8S_VERSION_FULL=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    K8S_VERSION_MINOR=$(echo "$K8S_VERSION_FULL" | cut -d. -f1,2)

    echo "Latest Kubernetes version: $K8S_VERSION_FULL"
    echo "Using repo version: $K8S_VERSION_MINOR"

    sudo install -m 0755 -d /etc/apt/keyrings

    curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION_MINOR}/deb/Release.key" \
        | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/${K8S_VERSION_MINOR}/deb/ /" \
        | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl

    sudo apt-mark hold kubelet kubeadm kubectl
    sudo systemctl enable --now kubelet
}

# =========================
# Main
# =========================
echo "Starting installation..."

if $SKIP_DOCKER && $SKIP_K8S; then
    echo "Nothing to install (both skipped)."
    exit 0
fi

$SKIP_DOCKER || install_docker
$SKIP_K8S || install_k8s

# =========================
# Summary
# =========================
echo ""
echo "Installation completed."
echo "Summary:"
$SKIP_DOCKER && echo "✗ Docker skipped" || echo "✓ Docker installed"
$SKIP_K8S && echo "✗ Kubernetes skipped" || echo "✓ Kubernetes installed"

echo ""
echo "Verify:"
$SKIP_DOCKER || echo "  docker --version"
$SKIP_K8S || echo "  kubeadm version"