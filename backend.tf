# Remote state backend.
#
# Create the storage account once (outside this repo or with a bootstrap config),
# then uncomment and fill in the block below before running `terraform init`.
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "playterry-tfstate-rg"
#     storage_account_name = "playterrytfstateprod"
#     container_name       = "tfstate"
#     key                  = "prod/playterry.tfstate"
#     use_azuread_auth     = true
#   }
# }
