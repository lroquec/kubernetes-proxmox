terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.68.0"
    }
  }
}
provider "proxmox" {
  endpoint = "https://pv02:8006"
  insecure = true
  username = "root@pam"
  password = var.root_password
  ssh {
    agent       = false
    private_key = file("~/.ssh/id_ed25519")
    username    = "root"
  }
}
