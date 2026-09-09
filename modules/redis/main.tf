###############################################################################
# Azure Cache for Redis (managed) - private endpoint only
###############################################################################

resource "azurerm_redis_cache" "this" {
  name                = "${var.name_prefix}-redis"
  location            = var.location
  resource_group_name = var.resource_group_name

  capacity      = var.capacity
  family        = var.family
  sku_name      = var.sku_name
  redis_version = var.redis_version

  minimum_tls_version  = var.minimum_tls_version
  non_ssl_port_enabled = false

  # Reachable only through the private endpoint below.
  public_network_access_enabled = false

  # Zone redundancy - Premium SKU only; empty on Standard/Basic.
  zones = length(var.zones) > 0 ? var.zones : null

  redis_configuration {
    maxmemory_policy = var.maxmemory_policy
  }

  tags = var.tags
}

###############################################################################
# Private DNS + private endpoint into the hub VNet
###############################################################################

resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${var.name_prefix}-redis-dnslink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name  = azurerm_private_dns_zone.redis.name
  virtual_network_id     = var.virtual_network_id
  registration_enabled   = false
  tags                   = var.tags
}

resource "azurerm_private_endpoint" "redis" {
  name                = "${var.name_prefix}-redis-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.this.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = var.tags
}
