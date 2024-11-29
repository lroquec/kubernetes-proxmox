variable "root_password" {
  description = "The root password for the VM"
  type        = string
  default     = "Enter123!"

}
variable "ssh_key" {
  description = "The SSH key for the VM"
  type        = string
  default     = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Pjg7YXZ8Yau9heCc4YWxFlzhThnI+IhUx2hLJRxYE Cloud-Init@Terraform"
}

variable "proxmox_host" {
  default = "pv02"
}
variable "template_name" {
  default = "ubuntu-2404-cloudinit-template"
}