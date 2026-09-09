resource "azurerm_mssql_managed_instance" "this" {
  name                = "${var.name_prefix}-sqlmi"
  location            = var.location
  resource_group_name = var.resource_group_name

  subnet_id = var.subnet_id

  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password

  license_type         = var.license_type
  sku_name             = var.sku_name
  vcores               = var.vcores
  storage_size_in_gb   = var.storage_size_in_gb
  storage_account_type = var.storage_account_type
  minimum_tls_version  = var.minimum_tls_version

  public_data_endpoint_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  timeouts {
    create = "6h"
    update = "6h"
    delete = "6h"
  }
}
