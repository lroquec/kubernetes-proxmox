resource "proxmox_vm_qemu" "cloudinit-example" {
  count = 3
  vmid        = 100
  name        = "kubeadm-vm-${count.index + 1}"
  target_node = var.proxmox_host
  agent       = 1
  cores       = 2
  memory      = 2048
  boot        = "order=scsi0" # has to be the same as the OS disk of the template
  clone       = var.template # The name of the template
  scsihw      = "virtio-scsi-single"
  vm_state    = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/kubeadm-cluster.yml" # /var/lib/vz/snippets/kubeadm-cluster.yml
  ciupgrade  = true
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip4=dhcp,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "root"
  cipassword = var.root_password
  sshkeys    = var.ssh_key

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = "local-lvm"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size    = "10G" 
        }
      }
    }
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
