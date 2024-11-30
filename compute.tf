resource "proxmox_virtual_environment_vm" "k8s-servers" {
  count     = 1
  vm_id     = "80${count.index + 1}"
  name      = "kubeadm-vm-${count.index + 1}"
  node_name = var.proxmox_host
  tags      = ["terraform", "k8s"]

  agent {
    enabled = true
  }

  clone {
    vm_id = var.template_id
    full  = true
  }

  # keep the first disk as boot disk
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 20
    file_format  = "raw"
    cache        = "writeback"
    iothread     = false
    ssd          = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
  }

  # Cloud-Init configuration
  initialization {
    interface           = "ide2"
    type                = "nocloud"
    vendor_data_file_id = "local:snippets/kubeadm-cluster.yml"
    ip_config {
      ipv4 {
        address = "192.168.5.19${count.index + 1}/24"
        gateway = "192.168.4.1"
      }
    }

    dns {
      servers = ["1.1.1.1"]
    }

    user_account {
      keys = [var.ssh_key]
    }

  }

  lifecycle {
    ignore_changes = [initialization["user_account"], ]
  }
}
