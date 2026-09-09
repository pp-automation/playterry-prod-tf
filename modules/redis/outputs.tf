output "id" {
  value = azurerm_redis_cache.this.id
}

output "name" {
  value = azurerm_redis_cache.this.name
}

output "hostname" {
  description = "Redis hostname - resolves to the private endpoint over the VNet / VPN."
  value       = azurerm_redis_cache.this.hostname
}

output "ssl_port" {
  value = azurerm_redis_cache.this.ssl_port
}

output "private_endpoint_ip" {
  description = "Private IP the Redis private endpoint was assigned in snet-redis."
  value       = azurerm_private_endpoint.redis.private_service_connection[0].private_ip_address
}

output "primary_access_key" {
  value     = azurerm_redis_cache.this.primary_access_key
  sensitive = true
}

output "primary_connection_string" {
  value     = azurerm_redis_cache.this.primary_connection_string
  sensitive = true
}
