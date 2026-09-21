resource "azurerm_virtual_network" "utility" {
  name                = "vnet-hmlb-util"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.utility.location
  resource_group_name = azurerm_resource_group.utility.name

  tags = local.common_tags
}

resource "azurerm_subnet" "utility" {
  name                 = "snet-hmlb-util"
  resource_group_name  = azurerm_resource_group.utility.name
  virtual_network_name = azurerm_virtual_network.utility.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "utility" {
  name                = "nsg-hmlb-util"
  location            = azurerm_resource_group.utility.location
  resource_group_name = azurerm_resource_group.utility.name

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "utility" {
  subnet_id                 = azurerm_subnet.utility.id
  network_security_group_id = azurerm_network_security_group.utility.id
}
