output "id" {
  value = azurerm_application_gateway.this.id
}

output "public_ip_address" {
  value = azurerm_public_ip.this.ip_address
}

output "backend_address_pool_name" {
  value = local.backend_pool_name
}
