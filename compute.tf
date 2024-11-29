resource "proxmox_vm_qemu" "cloudinit-k8s" {
  count            = 1
  vmid             = "40${count.index + 1}"
  name             = "kubeadm-vm-${count.index + 1}"
  target_node      = var.proxmox_host
  agent            = 1
  cores            = 2
  memory           = 2048
  bootdisk         = "scsi0"           # has to be the same as the OS disk of the template
  clone            = var.template_name # The name of the template
  scsihw           = "virtio-scsi-pci"
  automatic_reboot = true
  os_type = "cloud-init"

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/kubeadm-cluster.yml" # /var/lib/vz/snippets/kubeadm-cluster.yml
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip4=dhcp,ip6=dhcp"
  ciuser     = "root"
  cipassword = var.root_password
  sshkeys    = var.ssh_key

  disk {
    slot     = 0
    size     = "10G"
    type     = "scsi"
    storage  = "local-lvm"
    iothread = 1
  }

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}
