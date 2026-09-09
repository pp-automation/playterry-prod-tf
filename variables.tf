###############################################################################
# Core / naming
###############################################################################

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID to deploy the Playterry production environment into."
}

variable "brand" {
  type        = string
  description = "Brand name, used as the first token of every resource name."
  default     = "playterry"
}

variable "environment" {
  type        = string
  description = "Environment name, used as the second token of every resource name."
  default     = "prod"
}

variable "location" {
  type        = string
  description = "Azure region for all resources."
  default     = "westeurope"
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto every resource."
  default     = {}
}

###############################################################################
# Networking
###############################################################################

variable "vnet_address_space" {
  type        = list(string)
  description = "Address space of the hub VNet that hosts every subnet."
  default     = ["10.10.0.0/16"]
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
  description = "CIDR prefixes for each purpose-built subnet."
  default = {
    backoffice_aks = ["10.10.0.0/20"]
    web_aks        = ["10.10.16.0/20"]
    app_gateway    = ["10.10.32.0/24"]
    iis            = ["10.10.33.0/24"]
    sql_mi         = ["10.10.34.0/24"]
    gateway        = ["10.10.35.0/27"]
  }
}

###############################################################################
# Point-to-Site VPN
###############################################################################

variable "vpn" {
  type = object({
    sku                  = optional(string, "VpnGw1")
    generation           = optional(string, "Generation1")
    client_address_space = optional(list(string), ["172.16.0.0/24"])
    aad_tenant_id        = string
    aad_audience         = optional(string, "c632b3df-fb67-4d84-bdcf-b95ad541b5c8")
  })
  description = <<-EOT
    Point-to-Site Azure VPN gateway configuration.
      - aad_tenant_id: Entra ID tenant that authenticates VPN clients.
      - aad_audience:  Application ID of the "Azure VPN" enterprise app.
                       Default is the Azure Public cloud well-known ID.
      - client_address_space: pool handed to connected VPN clients
                              (must NOT overlap the VNet).
  EOT
}

###############################################################################
# AKS
###############################################################################

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes control-plane version. null lets AKS pick its default."
  default     = null
}

variable "aks_admin_group_object_ids" {
  type        = list(string)
  description = "Entra ID group object IDs granted cluster-admin via Azure RBAC for Kubernetes."
  default     = []
}

variable "aks_defaults" {
  type = object({
    sku_tier                = optional(string, "Standard")
    private_cluster_enabled = optional(bool, true)
    system_node_vm_size     = optional(string, "Standard_D4s_v5")
    system_node_min_count   = optional(number, 2)
    system_node_max_count   = optional(number, 4)
    workload_node_vm_size   = optional(string, "Standard_D8s_v5")
    workload_node_min_count = optional(number, 2)
    workload_node_max_count  = optional(number, 6)
    availability_zones      = optional(list(string), ["1", "2", "3"])
  })
  description = "Defaults applied to both AKS clusters (backoffice and web)."
  default     = {}
}

variable "aks_service_cidr" {
  type        = string
  description = "Kubernetes service CIDR (cluster-internal, must not overlap the VNet)."
  default     = "10.0.0.0/16"
}

variable "aks_dns_service_ip" {
  type        = string
  description = "Cluster DNS service IP, must sit inside aks_service_cidr."
  default     = "10.0.0.10"
}

variable "aks_pod_cidr" {
  type        = string
  description = "Overlay pod CIDR (must not overlap the VNet or the service CIDR)."
  default     = "10.244.0.0/16"
}

###############################################################################
# Per-cluster Azure Load Balancer (ingress VIP to the nodes)
###############################################################################

variable "load_balancer" {
  type = object({
    type               = optional(string, "internal") # "internal" | "public"
    backoffice_frontend_ip = optional(string)
    web_frontend_ip        = optional(string)
    rules = optional(list(object({
      name               = string
      protocol           = optional(string, "Tcp")
      frontend_port      = number
      backend_port       = number
      probe_protocol     = optional(string, "Tcp")
      probe_port         = optional(number)
      probe_request_path = optional(string)
    })), [
      {
        name          = "http"
        frontend_port = 80
        backend_port  = 80
      },
      {
        name          = "https"
        frontend_port = 443
        backend_port  = 443
      },
    ])
  })
  description = "Standard Azure Load Balancer placed in front of each AKS cluster's node subnet."
  default     = {}
}

###############################################################################
# Azure SQL Managed Instance
###############################################################################

variable "sql_managed_instance" {
  type = object({
    administrator_login          = optional(string, "playterryadmin")
    administrator_login_password  = optional(string)
    sku_name                     = optional(string, "GP_Gen5")
    vcores                       = optional(number, 4)
    storage_size_in_gb           = optional(number, 256)
    storage_account_type         = optional(string, "LRS")
    license_type                 = optional(string, "LicenseIncluded")
    minimum_tls_version          = optional(string, "1.2")
  })
  description = "Azure SQL Managed Instance sizing and admin credentials. Leave the password unset to auto-generate one."
  default     = {}
}

variable "sql_databases" {
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
    Databases to create on the SQL Managed Instance, keyed by database name.
    Empty by default - add entries as the application databases are decided, e.g.

      sql_databases = {
        DailyActionsDB       = {}
        DBA                  = {}
        ProgressPlayDBArchive = { short_term_retention_days = 14 }
        SystemParametersDB   = {}
        WiseSpinDB           = {}
      }
  EOT
  default     = {}
}

###############################################################################
# IIS web servers behind the Application Gateway
###############################################################################

variable "iis" {
  type = object({
    instance_count = optional(number, 2)
    vm_size        = optional(string, "Standard_D2s_v5")
    admin_username = optional(string, "iisadmin")
    admin_password = optional(string)
  })
  description = "Windows/IIS VM pool. Leave the password unset to auto-generate one."
  default     = {}
}

###############################################################################
# Application Gateway
###############################################################################

variable "application_gateway" {
  type = object({
    sku_name     = optional(string, "WAF_v2")
    sku_tier     = optional(string, "WAF_v2")
    min_capacity = optional(number, 2)
    max_capacity = optional(number, 10)
    enable_waf   = optional(bool, true)
    waf_mode     = optional(string, "Prevention")
  })
  description = "Application Gateway v2 in front of the IIS pool. Set enable_waf=false when using a Standard_v2 SKU."
  default     = {}
}
