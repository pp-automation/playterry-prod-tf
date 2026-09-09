variable "name_prefix" {
  type = string
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "gateway_subnet_id" {
  type        = string
  description = "ID of the subnet named \"GatewaySubnet\"."
}

variable "sku" {
  type    = string
  default = "VpnGw1"
}

variable "generation" {
  type    = string
  default = "Generation1"
}

variable "client_address_space" {
  type        = list(string)
  description = "Address pool handed to connected P2S clients. Must not overlap the VNet."
  default     = ["172.16.0.0/24"]
}

variable "aad_tenant_id" {
  type        = string
  description = "Entra ID tenant ID used to authenticate VPN clients."
}

variable "aad_audience" {
  type        = string
  description = "Application ID of the Azure VPN enterprise app (cloud-specific)."
  default     = "c632b3df-fb67-4d84-bdcf-b95ad541b5c8"
}

variable "tags" {
  type    = map(string)
  default = {}
}
