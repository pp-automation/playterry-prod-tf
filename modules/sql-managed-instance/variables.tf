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
  type        = string
  description = "Delegated subnet (Microsoft.Sql/managedInstances) with route table + NSG attached."
}

variable "administrator_login" {
  type = string
}

variable "administrator_login_password" {
  type      = string
  sensitive = true
}

variable "sku_name" {
  type    = string
  default = "GP_Gen5"
}

variable "vcores" {
  type    = number
  default = 4
}

variable "storage_size_in_gb" {
  type    = number
  default = 256
}

variable "storage_account_type" {
  type    = string
  default = "LRS"
}

variable "license_type" {
  type    = string
  default = "LicenseIncluded"
}

variable "minimum_tls_version" {
  type    = string
  default = "1.2"
}

variable "tags" {
  type    = map(string)
  default = {}
}
