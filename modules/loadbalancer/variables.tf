variable "name_prefix" {
  type = string
}

variable "name" {
  type        = string
  description = "Short identifier for this load balancer, e.g. \"backoffice\" or \"web\"."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet for the internal frontend (ignored when type = \"public\")."
}

variable "type" {
  type        = string
  description = "\"internal\" or \"public\"."
  default     = "internal"

  validation {
    condition     = contains(["internal", "public"], var.type)
    error_message = "type must be either \"internal\" or \"public\"."
  }
}

variable "private_ip_address" {
  type        = string
  description = "Static private IP for the internal frontend. null = dynamic."
  default     = null
}

variable "rules" {
  type = list(object({
    name               = string
    protocol           = optional(string, "Tcp")
    frontend_port      = number
    backend_port       = number
    probe_protocol     = optional(string, "Tcp")
    probe_port         = optional(number)
    probe_request_path = optional(string)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
