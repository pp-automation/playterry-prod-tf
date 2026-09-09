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

###############################################################################
# Databases hosted on the managed instance
###############################################################################

resource "azurerm_mssql_managed_database" "this" {
  for_each = var.databases

  name                = each.key
  managed_instance_id = azurerm_mssql_managed_instance.this.id
  collation           = each.value.collation

  short_term_retention_days = each.value.short_term_retention_days

  dynamic "long_term_retention_policy" {
    for_each = each.value.long_term_retention_policy == null ? [] : [each.value.long_term_retention_policy]

    content {
      weekly_retention  = long_term_retention_policy.value.weekly_retention
      monthly_retention = long_term_retention_policy.value.monthly_retention
      yearly_retention  = long_term_retention_policy.value.yearly_retention
      week_of_year      = long_term_retention_policy.value.week_of_year
    }
  }

  timeouts {
    create = "1h"
    delete = "1h"
  }
}
