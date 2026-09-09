output "resource_group_name" {
  description = "Resource group holding the Playterry production environment."
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "Hub VNet resource ID."
  value       = module.network.vnet_id
}

###############################################################################
# VPN
###############################################################################

output "vpn_gateway_public_ip" {
  description = "Public IP of the Point-to-Site VPN gateway (target for the Azure VPN client)."
  value       = module.vpn.public_ip_address
}

###############################################################################
# AKS
###############################################################################

output "aks_backoffice" {
  description = "Backoffice AKS cluster summary."
  value = {
    name                = module.aks_backoffice.cluster_name
    id                  = module.aks_backoffice.cluster_id
    node_resource_group = module.aks_backoffice.node_resource_group
    oidc_issuer_url     = module.aks_backoffice.oidc_issuer_url
    private_fqdn        = module.aks_backoffice.private_fqdn
  }
}

output "aks_web" {
  description = "Web AKS cluster summary."
  value = {
    name                = module.aks_web.cluster_name
    id                  = module.aks_web.cluster_id
    node_resource_group = module.aks_web.node_resource_group
    oidc_issuer_url     = module.aks_web.oidc_issuer_url
    private_fqdn        = module.aks_web.private_fqdn
  }
}

output "aks_backoffice_kube_config" {
  description = "Raw kubeconfig for the backoffice cluster (reachable over the VPN)."
  value       = module.aks_backoffice.kube_config_raw
  sensitive   = true
}

output "aks_web_kube_config" {
  description = "Raw kubeconfig for the web cluster (reachable over the VPN)."
  value       = module.aks_web.kube_config_raw
  sensitive   = true
}

###############################################################################
# Load balancers
###############################################################################

output "lb_backoffice" {
  description = "Backoffice cluster load balancer."
  value = {
    id                     = module.lb_backoffice.lb_id
    frontend_ip            = module.lb_backoffice.frontend_ip_address
    backend_address_pool_id = module.lb_backoffice.backend_address_pool_id
  }
}

output "lb_web" {
  description = "Web cluster load balancer."
  value = {
    id                      = module.lb_web.lb_id
    frontend_ip             = module.lb_web.frontend_ip_address
    backend_address_pool_id = module.lb_web.backend_address_pool_id
  }
}

###############################################################################
# SQL Managed Instance
###############################################################################

output "sql_managed_instance_fqdn" {
  description = "FQDN of the SQL Managed Instance."
  value       = module.sql.fqdn
}

output "sql_admin_login" {
  description = "SQL Managed Instance administrator login."
  value       = var.sql_managed_instance.administrator_login
}

output "sql_databases" {
  description = "Databases created on the SQL Managed Instance (name => resource ID)."
  value       = module.sql.database_ids
}

output "sql_admin_password" {
  description = "SQL Managed Instance administrator password (generated if not supplied)."
  value       = local.sql_admin_password
  sensitive   = true
}

###############################################################################
# Redis
###############################################################################

output "redis_hostname" {
  description = "Redis hostname (resolves to the private endpoint over the VNet / VPN)."
  value       = module.redis.hostname
}

output "redis_ssl_port" {
  description = "TLS port for Redis connections (non-TLS port is disabled)."
  value       = module.redis.ssl_port
}

output "redis_private_endpoint_ip" {
  description = "Private IP of the Redis private endpoint in snet-redis."
  value       = module.redis.private_endpoint_ip
}

output "redis_primary_access_key" {
  description = "Redis primary access key."
  value       = module.redis.primary_access_key
  sensitive   = true
}

output "redis_primary_connection_string" {
  description = "Redis primary connection string (StackExchange.Redis format)."
  value       = module.redis.primary_connection_string
  sensitive   = true
}

###############################################################################
# IIS + Application Gateway
###############################################################################

output "application_gateway_public_ip" {
  description = "Public IP of the Application Gateway in front of the IIS pool."
  value       = module.app_gateway.public_ip_address
}

output "iis_private_ips" {
  description = "Private IPs of the IIS servers."
  value       = module.iis.private_ip_addresses
}

output "iis_admin_username" {
  description = "Local administrator username on the IIS servers."
  value       = var.iis.admin_username
}

output "iis_admin_password" {
  description = "Local administrator password on the IIS servers (generated if not supplied)."
  value       = local.iis_admin_password
  sensitive   = true
}
