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

variable "databases" {
  type = map(object({
    collation                 = optional(string, "SQL_Latin1_General_CP1_CI_AS")
    short_term_retention_days = optional(number, 7)
    long_term_retention_policy = optional(object({
      weekly_retention  = optional(string)
      monthly_retention = optional(string)
      yearly_retention  = optional(string)
      week_of_year      = optional(number)
    }))
  }))
  description = <<-EOT
    Databases to create on the managed instance, keyed by database name, e.g.

      databases = {
        DailyActionsDB     = {}
        ProgressPlayDBArch = { short_term_retention_days = 14 }
      }

    Each value may set:
      - collation                 (ForceNew; default SQL_Latin1_General_CP1_CI_AS)
      - short_term_retention_days  (PITR window, 1-35 days; default 7)
      - long_term_retention_policy (weekly/monthly/yearly retention, ISO 8601 durations)
  EOT
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
