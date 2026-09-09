locals {
  backend_pool_name  = "iis-backend-pool"
  http_setting_name  = "iis-http-settings"
  listener_name      = "http-listener"
  frontend_port_name = "port-80"
  frontend_ip_name   = "public-frontend"
  probe_name         = "iis-health-probe"
  routing_rule_name  = "http-routing-rule"
}

resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-appgw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.name_prefix}-appgw"
  location            = var.location
  resource_group_name = var.resource_group_name
  zones               = ["1", "2", "3"]
  tags                = var.tags

  sku {
    name = var.sku_name
    tier = var.sku_tier
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_name
    public_ip_address_id = azurerm_public_ip.this.id
  }

  backend_address_pool {
    name         = local.backend_pool_name
    ip_addresses = var.backend_ip_addresses
  }

  probe {
    name                                      = local.probe_name
    protocol                                  = "Http"
    path                                      = var.health_probe_path
    pick_host_name_from_backend_http_settings  = true
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3

    match {
      status_code = ["200-399"]
    }
  }

  backend_http_settings {
    name                                = local.http_setting_name
    cookie_based_affinity               = "Disabled"
    port                                = var.backend_port
    protocol                            = "Http"
    request_timeout                     = 30
    probe_name                          = local.probe_name
    pick_host_name_from_backend_address = true
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name  = local.frontend_ip_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 100
  }

  dynamic "waf_configuration" {
    for_each = var.enable_waf ? [1] : []

    content {
      enabled          = true
      firewall_mode    = var.waf_mode
      rule_set_type    = "OWASP"
      rule_set_version = "3.2"
    }
  }
}
