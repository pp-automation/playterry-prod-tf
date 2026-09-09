variable "name_prefix" {
  type        = string
  description = "Prefix (brand-env) for resource names."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnet_prefixes" {
  type = object({
    backoffice_aks = list(string)
    web_aks        = list(string)
    app_gateway    = list(string)
    iis            = list(string)
    sql_mi         = list(string)
    gateway        = list(string)
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}
