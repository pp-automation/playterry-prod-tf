output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "backoffice_aks_subnet_id" {
  value = azurerm_subnet.backoffice_aks.id
}

output "web_aks_subnet_id" {
  value = azurerm_subnet.web_aks.id
}

output "app_gateway_subnet_id" {
  value = azurerm_subnet.app_gateway.id
}

output "iis_subnet_id" {
  value = azurerm_subnet.iis.id
}

output "sql_mi_subnet_id" {
  value = azurerm_subnet.sql_mi.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}
