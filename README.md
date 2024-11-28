# Cloud-Init Getting Started

This guide will help you get started with Cloud-Init on Proxmox Virtual Environment `PVE`. Cloud Init is a multi-distribution package that handles early initialization of a virtual machine. It is used for configuring the hostname, setting up SSH keys, and other tasks that need to be done before the virtual machine is ready for use.

Note: **all command are performed from the PVE shell**.

## Creating a Cloud Init Template

Before you can use Cloud-Init, you need to create a template that will be used to clone new virtual machines. This template will have the Cloud-Init package installed and configured. The following steps will guide you through creating a Cloud Init template:

### Downloading a Cloud-Init Image

For this guide, we will use the Ubuntu 24.04 LTS Cloud-Init image. You can download the image from the following link:

```bash
wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
```

### Install the tools for customize the image

```bash
sudo apt update -y && sudo apt install libguestfs-tools -y
```

### Install qemu-guest-agent

```bash
sudo virt-customize -a ubuntu-24.04-server-cloudimg-amd64.img --install qemu-guest-agent
```

### Importing the Cloud-Init Image

Before we can import the Cloud-Init image, we need to create a VM to give the image to. The following command will create a new VM with the ID `9000`:

```bash
sudo qm create 9000 --name "ubuntu-2404-cloudinit-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
sudo qm importdisk 9000 ubuntu-24.04-server-cloudimg-amd64.img local-zfs
sudo qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-zfs:vm-9000-disk-0
sudo qm set 9000 --boot c --bootdisk scsi0
sudo qm set 9000 --ide2 local-zfs:cloudinit
sudo qm set 9000 --serial0 socket --vga serial0
sudo qm set 9000 --agent enabled=1
```

Note: **Terraform is meant to manage the full life cycle of the VM, therefore we won't make any further changes to the VM**.

### Creating a Template from the VM

Now that we have the Cloud-Init image imported, we can create a template from the VM. The following command will convert the VM with ID `9000` to a template:

```bash
qm template 9000
```

## Creating a Snippet

Snippets are used to pass additional configuration to the Cloud-Init package. For this guide we will create a snippet that ensures the `qemu-guest-agent` package is installed on the virtual machine. Before we can create a snippet, we need to create a place to store it. Preferably in the same storage as the template. Do keep in mind that the cloned VMs can't start if the snippet is not accessible. Throughout this guide we will use the `local` storage.

```bash
mkdir /var/lib/vz/snippets
```

Now that we have a place to store the snippet, we can create the snippet itself. The following command will create a snippet that installs the `qemu-guest-agent.yml` package:

```bash
tee /var/lib/vz/snippets/qemu-guest-agent.yml <<EOF
#cloud-config
runcmd:
  - apt update
  - apt install -y containerd
  - systemctl enable --now containerd
  - apt-get install -y apt-transport-https ca-certificates curl gpg
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  - echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  - systemctl enable --now kubelet
EOF
```

## Creating the Proxmox user and role for terraform
The particular privileges required may change but here is a suitable starting point rather than using cluster-wide Administrator rights

Log into the Proxmox cluster or host using ssh (or mimic these in the GUI) then:

Create a new role for the future terraform user.
Create the user "terraform-prov@pve"
Add the TERRAFORM-PROV role to the terraform-prov user

```bash
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt"
pveum user add terraform-prov@pve --password <password>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```
## Exporting ENV variables for provider in your terraform host

```bash
export PM_USER="terraform-prov@pve"
export PM_PASS="password"
```