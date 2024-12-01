# Set up Kubernetes cluster in Proxmox with Terraform and Cloud-Init

This guide will help you deploy en kubernetes cluster through Kubeadm. The virtual machines for the cluster will be provisioned using Terraform and Cloud-Init on Proxmox Virtual Environment `PVE`. 

1. Use Terraform for creating the different VMs in Proxmox from a template from Ubuntu 24.04 LTS.
2. Cloud Init is a multi-distribution package that handles early initialization of a virtual machine. We use it to initialize the VMs with all the configs and packages necessary for kubeadm.
3. Use kubeadm for setting up a Kubernets cluster.

## Creating a Cloud-Init Template

Before you can use Cloud-Init, you need to create a template that will be used to clone new virtual machines. This template will have the Cloud-Init package installed and configured. The following steps will guide you through creating a Cloud Init template:

### Downloading a Cloud-Init Image

For this guide, we will use the Ubuntu 24.04 LTS Cloud-Init image. You can download the image from the following link:

```bash
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
```

### Install the tools for customize the image

```bash
apt update -y && apt install libguestfs-tools -y
```

### Install qemu-guest-agent

```bash
sudo virt-customize -a ubuntu-24.04-server-cloudimg-amd64.img --install qemu-guest-agent
```

### Importing the Cloud-Init Image

Before we can import the Cloud-Init image, we need to create a VM to give the image to. The following command will create a new VM with the ID `9000`:

```bash
sudo qm create 9000 --name "ubuntu-2404-cloudinit-template" --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0
sudo qm importdisk 9000 ubuntu-24.04-server-cloudimg-amd64.img local-lvm
sudo qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
sudo qm set 9000 --boot c --bootdisk scsi0
sudo qm set 9000 --ide2 local-lvm:cloudinit
sudo qm set 9000 --serial0 socket --vga serial0
sudo qm set 9000 --agent enabled=1
```

### Creating a Template from the VM

Now that we have the Cloud-Init image imported, we can create a template from the VM. The following command will convert the VM with ID `9000` to a template:

```bash
qm template 9000
```
### Generate the password for the user we will set up wih cloud-init and have it at hand

```bash
openssl passwd -6 "your_password"
```

## Creating a Snippet for VM initialization and installing and configuring requirements for a kubeadm successful installation.

Snippets are used to pass additional configuration to the Cloud-Init package. Before we can create a snippet, we need to create a place to store it. Preferably in the same storage as the template. Do keep in mind that the cloned VMs can't start if the snippet is not accessible. Throughout this guide we will use the `local` storage on Proxmox node.

```bash
mkdir /var/lib/vz/snippets
```

Now that we have a place to store the snippet, we can create the snippet itself. The following command will create a snippet that sets up a user and installs the `kubeadm` necessary requirements:

```bash
tee /var/lib/vz/snippets/kubeadm-cluster.yml <<EOF
#cloud-config
users:
  - name: laura
    gecos: Laura
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: pass ## hash generado con openssl passwd -6 "tu_contraseña"
    ssh_authorized_keys: 
      - ssh-ed25519 resto de tu llave publica
 
chpasswd:
  expire: false

preserve_hostname: false
manage_etc_hosts: true

runcmd:
  - rm -f /etc/machine-id
  - rm -f /var/lib/dbus/machine-id
  - systemd-machine-id-setup
  - rm -f /etc/ssh/ssh_host_*
  - dpkg-reconfigure openssh-server
  - apt update
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  - echo "overlay" | sudo tee -a /etc/modules-load.d/containerd.conf
  - echo "br_netfilter" | sudo tee -a /etc/modules-load.d/containerd.conf
  - modprobe overlay
  - modprobe br_netfilter
  - echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
  - echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
  - echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf
  - sysctl --system
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
  - add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  - apt update
  - apt install -y containerd.io
  - containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1
  - sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable --now containerd
  - apt-get install -y apt-transport-https ca-certificates curl gpg
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kub>
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  - systemctl enable --now kubelet
EOF
```
## Snippet break down

### User Configuration
Creates a user named `laura` with the following settings:
- **Full Name**: Laura
- **Shell**: `/bin/bash`
- **Sudo Access**: Passwordless sudo for all commands (`NOPASSWD`)
- **Password**: We have this from previous step `Generate the password...`
- **SSH Access**: Adds a specified SSH public key for secure remote access

### Password Management
- Password expiration is disabled: `expire: false`

### Hostname and Host File Management
- Hostname changes during initialization are allowed: `preserve_hostname: false`
- The `/etc/hosts` file is automatically managed by cloud-init: `manage_etc_hosts: true`

### Commands in runcmd

Below is a detailed explanation of the commands used for preparing a system to install Kubernetes with `kubeadm`:

#### Clear Machine Identifiers and regenerate ssh hosts keys. This is the only step that is not a requirement from Kubernetes but recommended of you use image clones as we do.
- `rm -f /etc/machine-id`: Deletes the existing machine ID to reset it.
- `rm -f /var/lib/dbus/machine-id`: Deletes the D-Bus machine ID for consistency with the system's new identity.
- `systemd-machine-id-setup`: Regenerates the system's machine ID.
- `rm -f /etc/ssh/ssh_host_*`: Removes old SSH host keys.
- `dpkg-reconfigure openssh-server`: Reconfigures the OpenSSH server and regenerates host keys.

#### Update System Packages
- `apt update`: Updates the local package index to ensure access to the latest package versions.

#### Disable and Remove Swap
- `swapoff -a`: Temporarily disables swap space, which is required for Kubernetes.
- `sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab`: Permanently disables swap by commenting out its entry in `/etc/fstab`.

#### Load Required Kernel Modules
- `echo "overlay" | sudo tee -a /etc/modules-load.d/containerd.conf`: Configures the `overlay` kernel module to load at boot.
- `echo "br_netfilter" | sudo tee -a /etc/modules-load.d/containerd.conf`: Configures the `br_netfilter` module for networking.
- `modprobe overlay`: Loads the `overlay` kernel module immediately.
- `modprobe br_netfilter`: Loads the `br_netfilter` module immediately.

#### Configure Sysctl for Networking
- `echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf`: Enables bridge IPv6 traffic to be processed by iptables.
- `echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf`: Enables bridge IPv4 traffic to be processed by iptables.
- `echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.d/kubernetes.conf`: Enables IPv4 forwarding.
- `sysctl --system`: Applies all the sysctl settings immediately.

#### Install and Configure Containerd
- `curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg`: Adds Docker's GPG key for secure package installation.
- `add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"`: Adds Docker's repository.
- `apt update`: Updates the package index to include Docker's repository.
- `apt install -y containerd.io`: Installs the Containerd runtime.
- `containerd config default | tee /etc/containerd/config.toml >/dev/null 2>&1`: Generates a default configuration for Containerd.
- `sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml`: Configures Containerd to use systemd as the cgroup driver.
- `systemctl restart containerd`: Restarts the Containerd service.
- `systemctl enable --now containerd`: Enables and starts the Containerd service.

#### Install Kubernetes Tools
- `apt-get install -y apt-transport-https ca-certificates curl gpg`: Installs required dependencies.
- `curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg`: Adds Kubernetes' GPG key for secure package installation.
- `echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list`: Adds Kubernetes' repository.
- `apt-get update`: Updates the package index to include Kubernetes' repository.
- `apt-get install -y kubelet kubeadm kubectl`: Installs Kubernetes tools (`kubelet`, `kubeadm`, and `kubectl`).
- `apt-mark hold kubelet kubeadm kubectl`: Prevents the Kubernetes tools from being updated automatically.
- `systemctl enable --now kubelet`: Enables and starts the Kubernetes Kubelet service.

This setup ensures the system is ready for a Kubernetes cluster deployment using `kubeadm`.

# Run Terraform

```bash
terraform init
terraform apply
```

# Kubeadm init

In my case I was using 192.168.x.x as my local network so I could not use the normal init

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```
## Set up kubectl

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "alias k='kubectl'" >> ~/.bashrc
complete -o default -F __start_kubectl k
```

## Network plugin
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

## Reset kubeadm in case anything to strange (always check the network specially if using cloud init images)

```bash
sudo kubeadm reset
sudo rm -rf /etc/kubernetes/
sudo rm -rf /var/lib/etcd /var/lib/kubelet /var/lib/dockershim
sudo rm -rf /var/lib/cni /run/cni /etc/cni/net.d
sudo rm -rf /var/log/pods /var/log/containers
sudo systemctl restart containerd
sudo systemctl restart kubelet

sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

#### References used
https://www.trfore.com/posts/provisioning-proxmox-8-vms-with-terraform-and-bpg/
https://github.com/Telmate/terraform-provider-proxmox/blob/master/docs/guides/cloud-init%20getting%20started.md
https://hbayraktar.medium.com/how-to-install-kubernetes-cluster-on-ubuntu-22-04-step-by-step-guide-7dbf7e8f5f99

## To do
Rewrite for using terraform also for template generation and snippet creation.