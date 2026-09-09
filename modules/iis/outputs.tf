output "private_ip_addresses" {
  description = "Private IPs of the IIS NICs - feed straight into the Application Gateway backend pool."
  value       = [for nic in azurerm_network_interface.this : nic.private_ip_address]
}

output "vm_ids" {
  value = [for vm in azurerm_windows_virtual_machine.this : vm.id]
}

output "vm_names" {
  value = [for vm in azurerm_windows_virtual_machine.this : vm.name]
}

output "availability_set_id" {
  value = azurerm_availability_set.this.id
}
