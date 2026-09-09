locals {
  name_prefix = "${var.brand}-${var.environment}"

  base_tags = merge({
    brand       = var.brand
    environment = var.environment
    managed_by  = "terraform"
    workload    = "playterry-platform"
  }, var.tags)

  # Auto-generate secrets when the caller did not supply them.
  sql_admin_password = coalesce(
    try(var.sql_managed_instance.administrator_login_password, null),
    try(random_password.sql[0].result, null),
  )

  iis_admin_password = coalesce(
    try(var.iis.admin_password, null),
    try(random_password.iis[0].result, null),
  )
}

resource "random_password" "sql" {
  count = try(var.sql_managed_instance.administrator_login_password, null) == null ? 1 : 0

  length           = 24
  special          = true
  override_special = "!#%*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "iis" {
  count = try(var.iis.admin_password, null) == null ? 1 : 0

  length           = 20
  special          = true
  override_special = "!#%*()-_=+"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

###############################################################################
# Resource group + shared observability
###############################################################################

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.base_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.base_tags
}

###############################################################################
# Networking
###############################################################################

module "network" {
  source = "./modules/network"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_address_space  = var.vnet_address_space
  subnet_prefixes     = var.subnet_prefixes
  tags                = local.base_tags
}

###############################################################################
# Point-to-Site VPN
###############################################################################

module "vpn" {
  source = "./modules/vpn-p2s"

  name_prefix          = local.name_prefix
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  gateway_subnet_id    = module.network.gateway_subnet_id
  sku                  = var.vpn.sku
  generation           = var.vpn.generation
  client_address_space = var.vpn.client_address_space
  aad_tenant_id        = var.vpn.aad_tenant_id
  aad_audience         = var.vpn.aad_audience
  tags                 = local.base_tags
}

###############################################################################
# AKS clusters
###############################################################################

module "aks_backoffice" {
  source = "./modules/aks"

  name_prefix                = local.name_prefix
  cluster_name               = "backoffice"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  node_subnet_id             = module.network.backoffice_aks_subnet_id
  kubernetes_version         = var.kubernetes_version
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  admin_group_object_ids     = var.aks_admin_group_object_ids

  sku_tier                = var.aks_defaults.sku_tier
  private_cluster_enabled = var.aks_defaults.private_cluster_enabled
  system_node_vm_size     = var.aks_defaults.system_node_vm_size
  system_node_min_count   = var.aks_defaults.system_node_min_count
  system_node_max_count   = var.aks_defaults.system_node_max_count
  workload_node_vm_size   = var.aks_defaults.workload_node_vm_size
  workload_node_min_count = var.aks_defaults.workload_node_min_count
  workload_node_max_count = var.aks_defaults.workload_node_max_count
  availability_zones      = var.aks_defaults.availability_zones

  service_cidr   = var.aks_service_cidr
  dns_service_ip = var.aks_dns_service_ip
  pod_cidr       = var.aks_pod_cidr

  tags = local.base_tags
}

module "aks_web" {
  source = "./modules/aks"

  name_prefix                = local.name_prefix
  cluster_name               = "web"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  node_subnet_id             = module.network.web_aks_subnet_id
  kubernetes_version         = var.kubernetes_version
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  admin_group_object_ids     = var.aks_admin_group_object_ids

  sku_tier                = var.aks_defaults.sku_tier
  private_cluster_enabled = var.aks_defaults.private_cluster_enabled
  system_node_vm_size     = var.aks_defaults.system_node_vm_size
  system_node_min_count   = var.aks_defaults.system_node_min_count
  system_node_max_count   = var.aks_defaults.system_node_max_count
  workload_node_vm_size   = var.aks_defaults.workload_node_vm_size
  workload_node_min_count = var.aks_defaults.workload_node_min_count
  workload_node_max_count = var.aks_defaults.workload_node_max_count
  availability_zones      = var.aks_defaults.availability_zones

  service_cidr   = var.aks_service_cidr
  dns_service_ip = var.aks_dns_service_ip
  pod_cidr       = var.aks_pod_cidr

  tags = local.base_tags
}

###############################################################################
# Per-cluster Azure Load Balancers
###############################################################################

module "lb_backoffice" {
  source = "./modules/loadbalancer"

  name_prefix         = local.name_prefix
  name                = "backoffice"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.backoffice_aks_subnet_id
  type                = var.load_balancer.type
  private_ip_address  = var.load_balancer.backoffice_frontend_ip
  rules               = var.load_balancer.rules
  tags                = local.base_tags
}

module "lb_web" {
  source = "./modules/loadbalancer"

  name_prefix         = local.name_prefix
  name                = "web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.web_aks_subnet_id
  type                = var.load_balancer.type
  private_ip_address  = var.load_balancer.web_frontend_ip
  rules               = var.load_balancer.rules
  tags                = local.base_tags
}

###############################################################################
# Azure SQL Managed Instance
###############################################################################

module "sql" {
  source = "./modules/sql-managed-instance"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.sql_mi_subnet_id

  administrator_login          = var.sql_managed_instance.administrator_login
  administrator_login_password = local.sql_admin_password
  sku_name                     = var.sql_managed_instance.sku_name
  vcores                       = var.sql_managed_instance.vcores
  storage_size_in_gb           = var.sql_managed_instance.storage_size_in_gb
  storage_account_type         = var.sql_managed_instance.storage_account_type
  license_type                 = var.sql_managed_instance.license_type
  minimum_tls_version          = var.sql_managed_instance.minimum_tls_version

  tags = local.base_tags

  # The subnet delegation, route table and NSG must exist first.
  depends_on = [module.network]
}

###############################################################################
# IIS web servers + Application Gateway
###############################################################################

module "iis" {
  source = "./modules/iis"

  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = module.network.iis_subnet_id
  instance_count      = var.iis.instance_count
  vm_size             = var.iis.vm_size
  admin_username      = var.iis.admin_username
  admin_password      = local.iis_admin_password
  tags                = local.base_tags
}

module "app_gateway" {
  source = "./modules/application-gateway"

  name_prefix          = local.name_prefix
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  subnet_id            = module.network.app_gateway_subnet_id
  backend_ip_addresses = module.iis.private_ip_addresses
  sku_name             = var.application_gateway.sku_name
  sku_tier             = var.application_gateway.sku_tier
  min_capacity         = var.application_gateway.min_capacity
  max_capacity         = var.application_gateway.max_capacity
  enable_waf           = var.application_gateway.enable_waf
  waf_mode             = var.application_gateway.waf_mode
  tags                 = local.base_tags
}
