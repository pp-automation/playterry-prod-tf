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

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet that hosts the Redis private endpoint (snet-redis)."
}

variable "virtual_network_id" {
  type        = string
  description = "Hub VNet ID - linked to the privatelink.redis.cache.windows.net private DNS zone."
}

variable "sku_name" {
  type    = string
  default = "Standard"
}

variable "family" {
  type        = string
  default     = "C"
  description = "\"C\" for Basic/Standard, \"P\" for Premium."
}

variable "capacity" {
  type        = number
  default     = 3
  description = "Size within the family. Standard C: 1=1GB 2=2.5GB 3=6GB 4=13GB."
}

variable "redis_version" {
  type    = string
  default = "6"
}

variable "minimum_tls_version" {
  type    = string
  default = "1.2"
}

variable "zones" {
  type        = list(string)
  default     = []
  description = "Availability zones. Premium SKU only - leave [] for Basic/Standard."
}

variable "maxmemory_policy" {
  type        = string
  default     = "allkeys-lru"
  description = "Eviction policy once maxmemory is reached (cache-style default)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
