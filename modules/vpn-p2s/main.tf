resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-vpngw-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "this" {
  name                = "${var.name_prefix}-vpngw"
  location            = var.location
  resource_group_name = var.resource_group_name

  type       = "Vpn"
  vpn_type   = "RouteBased"
  sku        = var.sku
  generation = var.generation

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.this.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  # Point-to-Site with Microsoft Entra ID authentication.
  vpn_client_configuration {
    address_space        = var.client_address_space
    vpn_client_protocols = ["OpenVPN"]

    aad_tenant   = "https://login.microsoftonline.com/${var.aad_tenant_id}/"
    aad_audience = var.aad_audience
    aad_issuer   = "https://sts.windows.net/${var.aad_tenant_id}/"
  }

  tags = var.tags
}
