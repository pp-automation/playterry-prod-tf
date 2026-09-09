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

output "database_ids" {
  description = "Map of database name => resource ID for every database created on the instance."
  value       = { for name, db in azurerm_mssql_managed_database.this : name => db.id }
}

output "database_names" {
  description = "Names of the databases created on the instance."
  value       = sort(keys(azurerm_mssql_managed_database.this))
}
