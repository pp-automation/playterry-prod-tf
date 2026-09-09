output "id" {
  value = azurerm_mssql_managed_instance.this.id
}

output "name" {
  value = azurerm_mssql_managed_instance.this.name
}

output "fqdn" {
  value = azurerm_mssql_managed_instance.this.fqdn
}

output "identity_principal_id" {
  value = azurerm_mssql_managed_instance.this.identity[0].principal_id
}
