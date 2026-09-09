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
  description = "Dedicated Application Gateway subnet."
}

variable "backend_ip_addresses" {
  type        = list(string)
  description = "Private IPs of the IIS servers."
}

variable "sku_name" {
  type    = string
  default = "WAF_v2"
}

variable "sku_tier" {
  type    = string
  default = "WAF_v2"
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 10
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "waf_mode" {
  type    = string
  default = "Prevention"
}

variable "backend_port" {
  type    = number
  default = 80
}

variable "health_probe_path" {
  type    = string
  default = "/"
}

variable "tags" {
  type    = map(string)
  default = {}
}
