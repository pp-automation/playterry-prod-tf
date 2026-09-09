variable "name_prefix" {
  type        = string
  description = "Prefix (brand-env) for resource names."
}

variable "cluster_name" {
  type        = string
  description = "Short cluster identifier, e.g. \"backoffice\" or \"web\"."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "node_subnet_id" {
  type        = string
  description = "Subnet the node pools attach to."
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}

variable "sku_tier" {
  type    = string
  default = "Standard"
}

variable "private_cluster_enabled" {
  type    = bool
  default = true
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_D4s_v5"
}

variable "system_node_min_count" {
  type    = number
  default = 2
}

variable "system_node_max_count" {
  type    = number
  default = 4
}

variable "workload_node_vm_size" {
  type    = string
  default = "Standard_D8s_v5"
}

variable "workload_node_min_count" {
  type    = number
  default = 2
}

variable "workload_node_max_count" {
  type    = number
  default = 6
}

variable "availability_zones" {
  type    = list(string)
  default = ["1", "2", "3"]
}

variable "service_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.0.0.10"
}

variable "pod_cidr" {
  type    = string
  default = "10.244.0.0/16"
}

variable "tags" {
  type    = map(string)
  default = {}
}
