resource "azurerm_availability_set" "this" {
  name                         = "${var.name_prefix}-iis-avset"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
  tags                         = var.tags
}

resource "azurerm_network_interface" "this" {
  count = var.instance_count

  name                = "${var.name_prefix}-iis-${format("%02d", count.index + 1)}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "this" {
  count = var.instance_count

  name                = "${var.name_prefix}-iis-${format("%02d", count.index + 1)}"
  computer_name       = "iis-${format("%02d", count.index + 1)}"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  availability_set_id = azurerm_availability_set.this.id
  provision_vm_agent  = true

  network_interface_ids = [azurerm_network_interface.this[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  tags = var.tags
}

# Install the IIS role and drop a per-host landing page.
resource "azurerm_virtual_machine_extension" "iis" {
  count = var.instance_count

  name                       = "install-iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.this[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name Web-Server,Web-Mgmt-Tools; Set-Content -Path C:\\inetpub\\wwwroot\\index.html -Value ('<h1>Playterry IIS - ' + $env:COMPUTERNAME + '</h1>')\""
  })

  tags = var.tags
}
