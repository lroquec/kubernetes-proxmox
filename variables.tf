variable "root_password" {
  description = "The root password for the VM"
  type        = string
}
variable "ssh_key" {
  description = "The SSH key for the VM"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Pjg7YXZ8Yau9heCc4YWxFlzhThnI+IhUx2hLJRxYE Cloud-Init@Terraform"
}

variable "proxmox_host" {
  default = "pve2"
}
variable "template_id" {
  default = 9000
}