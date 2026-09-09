variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_count" {
  type    = number
  default = 2
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v5"
}

variable "admin_username" {
  type    = string
  default = "iisadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "image" {
  type = object({
    publisher = optional(string, "MicrosoftWindowsServer")
    offer     = optional(string, "WindowsServer")
    sku       = optional(string, "2022-datacenter-azure-edition")
    version   = optional(string, "latest")
  })
  default = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
