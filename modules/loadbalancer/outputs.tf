output "lb_id" {
  value = azurerm_lb.this.id
}

output "backend_address_pool_id" {
  value = azurerm_lb_backend_address_pool.nodes.id
}

output "frontend_ip_address" {
  description = "Private IP (internal) or public IP (public) of the load balancer frontend."
  value = local.is_internal ? (
    azurerm_lb.this.frontend_ip_configuration[0].private_ip_address
  ) : azurerm_public_ip.this[0].ip_address
}
