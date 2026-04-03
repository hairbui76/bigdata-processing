#!/bin/bash
set -euo pipefail

if command -v kubeadm >/dev/null 2>&1; then
  # -f/--force: no interactive prompt
  # Do NOT let kubeadm reset non-zero stop the script (common when CRI cleanup fails)
  sudo kubeadm reset --force || true
else
  echo "  - kubeadm not found, skipping kubeadm reset"
fi

echo "[2/6] Remove CNI + kubeconfig ..."
sudo rm -rf /etc/cni/net.d || true
rm -f "$HOME/.kube/config" || true

echo "[3/6] Remove leftover network interfaces (if exist) ..."
sudo ip link del flannel.1 2>/dev/null || true
sudo ip link del cni0 2>/dev/null || true

echo "[4/6] Kill common kube ports (ignore if not running) ..."
sudo fuser -k 6443/tcp 2>/dev/null || true
sudo fuser -k 10259/tcp 2>/dev/null || true
sudo fuser -k 10257/tcp 2>/dev/null || true

echo "[5/6] Clear IPVS and kube-related iptables chains (best-effort) ..."
sudo ipvsadm --clear 2>/dev/null || true

# Delete jumps (ignore errors if rules/chains don't exist)
sudo iptables -D INPUT   -m conntrack --ctstate NEW -m comment --comment "kubernetes load balancer firewall" -j KUBE-PROXY-FIREWALL 2>/dev/null || true
sudo iptables -D INPUT   -m comment --comment "kubernetes health check service ports" -j KUBE-NODEPORTS 2>/dev/null || true
sudo iptables -D INPUT   -m conntrack --ctstate NEW -m comment --comment "kubernetes externally-visible service portals" -j KUBE-EXTERNAL-SERVICES 2>/dev/null || true
sudo iptables -D INPUT   -j KUBE-FIREWALL 2>/dev/null || true

sudo iptables -D FORWARD -m conntrack --ctstate NEW -m comment --comment "kubernetes load balancer firewall" -j KUBE-PROXY-FIREWALL 2>/dev/null || true
sudo iptables -D FORWARD -m comment --comment "kubernetes forwarding rules" -j KUBE-FORWARD 2>/dev/null || true
sudo iptables -D FORWARD -m conntrack --ctstate NEW -m comment --comment "kubernetes service portals" -j KUBE-SERVICES 2>/dev/null || true
sudo iptables -D FORWARD -m conntrack --ctstate NEW -m comment --comment "kubernetes externally-visible service portals" -j KUBE-EXTERNAL-SERVICES 2>/dev/null || true

sudo iptables -D OUTPUT  -m conntrack --ctstate NEW -m comment --comment "kubernetes load balancer firewall" -j KUBE-PROXY-FIREWALL 2>/dev/null || true
sudo iptables -D OUTPUT  -m conntrack --ctstate NEW -m comment --comment "kubernetes service portals" -j KUBE-SERVICES 2>/dev/null || true
sudo iptables -D OUTPUT  -j KUBE-FIREWALL 2>/dev/null || true

for c in KUBE-EXTERNAL-SERVICES KUBE-FIREWALL KUBE-FORWARD KUBE-KUBELET-CANARY KUBE-NODEPORTS KUBE-PROXY-CANARY KUBE-PROXY-FIREWALL KUBE-SERVICES; do
  sudo iptables -F "$c" 2>/dev/null || true
  sudo iptables -X "$c" 2>/dev/null || true
done

echo "[6/6] Disable swap (runtime + fstab) ..."
sudo swapoff -a || true
# Comment out any swap entries in /etc/fstab (safe, idempotent)
sudo sed -i.bak -E 's/^([^#].*\s+swap\s+.*)$/# \1/g' /etc/fstab

echo "Enable br_netfilter module + sysctl ..."
# Load now
sudo modprobe br_netfilter || true
# Persist module across reboot
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
# Persist sysctl across reboot
cat <<'EOF' | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf >/dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system >/dev/null || true

echo "Containerd: set SystemdCgroup=true (if containerd exists) ..."
if command -v containerd >/dev/null 2>&1; then
  sudo mkdir -p /etc/containerd
  sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
  sudo sed -i -E 's/^\s*SystemdCgroup\s*=\s*false\s*$/SystemdCgroup = true/' /etc/containerd/config.toml
  sudo systemctl restart containerd 2>/dev/null || true
else
  echo "  - containerd not found, skipping containerd config"
fi

echo "Restart kubelet/docker if present (best-effort) ..."
sudo systemctl restart docker 2>/dev/null || true
sudo systemctl restart kubelet 2>/dev/null || true

echo
echo "If you want to init a cluster, run the commands below, please notice 10.244.0.0/16 is for Flannel:"
echo "  sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
echo
echo "Then set kubeconfig:"
echo "  mkdir -p \$HOME/.kube"
echo "  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo
echo "Optional: untaint control-plane to schedule pods:"
echo "  kubectl taint nodes --all node-role.kubernetes.io/control-plane-"