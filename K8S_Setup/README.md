# Hướng Dẫn K8S Setup

README này hướng dẫn nhanh 2 bước cơ bản để:
- Cài đặt Docker + Kubernetes tools (`kubelet`, `kubeadm`, `kubectl`)
- Fresh/reset môi trường Kubernetes khi cần làm lại từ đầu

## Yêu cầu trước khi chạy

- OS: Ubuntu/Debian (script dùng `apt-get`)
- Có quyền `sudo`
- Có kết nối Internet để tải package

## Bước 1: Chạy `init.sh` để cài Docker + Kubernetes

Script `init.sh` sẽ:
- Cài Docker CE (`docker-ce`, `docker-ce-cli`, `containerd.io`, ...)
- Tự động lấy Kubernetes stable version mới nhất
- Cài `kubelet`, `kubeadm`, `kubectl`
- `apt-mark hold` các gói Kubernetes để tránh bị nâng cấp vô tình

### Cách chạy

```bash
cd K8S_Setup
chmod +x init.sh
./init.sh
```

### Các tùy chọn hỗ trợ

```bash
./init.sh --skip-docker   # Bỏ qua cài Docker
./init.sh --skip-k8s      # Bỏ qua cài Kubernetes tools
./init.sh -h              # Xem trợ giúp
```

### Kiểm tra sau cài đặt

```bash
docker --version
kubeadm version
kubectl version --client
```

## Bước 2: Chạy `flush.sh` để fresh môi trường

Script `flush.sh` dùng để reset Kubernetes về trạng thái "sạch" để có thể `kubeadm init` lại.

Nó sẽ thực hiện (best-effort):
- `kubeadm reset --force`
- Xóa CNI config và kubeconfig cũ
- Dọn network interface còn dư (`flannel.1`, `cni0`)
- Dọn một số iptables/IPVS rule của Kubernetes
- Tắt swap và cập nhật `fstab`
- Bật `br_netfilter`, set sysctl cần thiết cho Kubernetes
- Chỉnh containerd `SystemdCgroup=true`
- Restart lại `containerd`/`docker`/`kubelet` nếu có

### Cách chạy

```bash
cd K8S_Setup
chmod +x flush.sh
./flush.sh
```

Sau khi fresh, script sẽ in gợi ý lệnh tạo cluster lại:

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

> Nếu muốn schedule pod trên master node, thì chạy lệnh taint sau:

```bash
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

## Luồng sử dụng khuyến nghị

1. Máy mới/chưa cài gì: chạy `./init.sh`
2. Đã từng init cluster, muốn làm lại từ đầu: chạy `./flush.sh`, sau đó `kubeadm init` lại

## Lưu ý

- `flush.sh` có can thiệp vào network và firewall rules, chỉ dùng trên máy dev/test mà bạn chủ động quản lý.
- Nếu bạn đang dùng distro không phải Ubuntu/Debian, cần sửa script cài đặt package manager cho phù hợp.

## Bước 3: Sau khi đã có cluster, bạn PHẢI cài thêm CNI plugin (ở đây dùng Flannel) để cluster hoạt động bình thường:

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

## Bước 4: Kiểm tra các pod xem có hoạt động không:

```bash
kubectl get pods -A

# NAMESPACE      NAME                            READY   STATUS    RESTARTS   AGE
# kube-flannel   kube-flannel-ds-ftgrk           1/1     Running   0          64s
# kube-system    coredns-7d764666f9-2q2v5        1/1     Running   0          11m
# kube-system    coredns-7d764666f9-r27n5        1/1     Running   0          11m
# kube-system    etcd-node1                      1/1     Running   6          11m
# kube-system    kube-apiserver-node1            1/1     Running   0          11m
# kube-system    kube-controller-manager-node1   1/1     Running   0          11m
# kube-system    kube-proxy-v9crd                1/1     Running   0          11m
# kube-system    kube-scheduler-node1            1/1     Running   0          11m
```
