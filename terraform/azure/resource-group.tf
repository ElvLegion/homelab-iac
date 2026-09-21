resource "azurerm_resource_group" "utility" {
  name     = "rg-hmlb-util"
  location = local.location

  tags = local.common_tags
}
