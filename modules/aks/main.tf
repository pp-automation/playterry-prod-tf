resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.name_prefix}-${var.cluster_name}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  node_resource_group = "${var.name_prefix}-${var.cluster_name}-aks-nodes-rg"
  dns_prefix          = "${var.name_prefix}-${var.cluster_name}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # Private control plane - reachable only from inside the VNet / over the VPN.
  private_cluster_enabled             = var.private_cluster_enabled
  private_dns_zone_id                 = var.private_cluster_enabled ? "System" : null
  private_cluster_public_fqdn_enabled = false

  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  role_based_access_control_enabled  = true
  local_account_disabled            = false

  default_node_pool {
    name                        = "system"
    vm_size                     = var.system_node_vm_size
    vnet_subnet_id              = var.node_subnet_id
    orchestrator_version        = var.kubernetes_version
    auto_scaling_enabled        = true
    min_count                   = var.system_node_min_count
    max_count                   = var.system_node_max_count
    zones                       = var.availability_zones
    os_sku                      = "Ubuntu"
    max_pods                    = 110
    only_critical_addons_enabled = true
    temporary_name_for_rotation = "systmp"

    upgrade_settings {
      max_surge = "33%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    pod_cidr            = var.pod_cidr
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].orchestrator_version,
    ]
  }
}

# Workloads land here; the system pool carries the CriticalAddonsOnly taint.
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.workload_node_vm_size
  vnet_subnet_id        = var.node_subnet_id
  orchestrator_version  = var.kubernetes_version
  auto_scaling_enabled  = true
  min_count             = var.workload_node_min_count
  max_count             = var.workload_node_max_count
  zones                 = var.availability_zones
  os_sku                = "Ubuntu"
  mode                  = "User"
  max_pods              = 110

  upgrade_settings {
    max_surge = "33%"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [orchestrator_version]
  }
}
