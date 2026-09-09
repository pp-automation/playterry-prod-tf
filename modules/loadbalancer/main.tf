locals {
  is_internal      = var.type == "internal"
  frontend_ip_name = "frontend"
  rules_by_name    = { for r in var.rules : r.name => r }
}

resource "azurerm_public_ip" "this" {
  count = local.is_internal ? 0 : 1

  name                = "${var.name_prefix}-${var.name}-lb-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "${var.name_prefix}-${var.name}-lb"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = local.frontend_ip_name
    subnet_id                     = local.is_internal ? var.subnet_id : null
    private_ip_address_allocation = local.is_internal ? (var.private_ip_address == null ? "Dynamic" : "Static") : null
    private_ip_address            = local.is_internal ? var.private_ip_address : null
    public_ip_address_id          = local.is_internal ? null : azurerm_public_ip.this[0].id
    zones                         = local.is_internal ? ["1", "2", "3"] : null
  }
}

# AKS attaches node NICs / VMSS instances to this pool via a Kubernetes
# Service of type LoadBalancer (see the repo README for the annotation).
resource "azurerm_lb_backend_address_pool" "nodes" {
  name            = "${var.name}-nodes"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "this" {
  for_each = local.rules_by_name

  name                = "${each.value.name}-probe"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = each.value.probe_protocol
  port                = coalesce(each.value.probe_port, each.value.backend_port)
  request_path        = lower(each.value.probe_protocol) == "http" ? coalesce(each.value.probe_request_path, "/") : null
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "this" {
  for_each = local.rules_by_name

  name                           = each.value.name
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = each.value.protocol
  frontend_port                  = each.value.frontend_port
  backend_port                   = each.value.backend_port
  frontend_ip_configuration_name = local.frontend_ip_name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.nodes.id]
  probe_id                       = azurerm_lb_probe.this[each.key].id
  idle_timeout_in_minutes        = 4
}
