terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "2.9.8"
    }
  }
}

provider "proxmox" {
  # Configuration options
  pm_api_url      = "https://pv02:8006/api2/json"
  pm_tls_insecure = true
}