resource "azurerm_public_ip" "utility" {
  name                = "pip-hmlb-util"
  location            = azurerm_resource_group.utility.location
  resource_group_name = azurerm_resource_group.utility.name

  allocation_method = "Static"
  sku               = "Standard"

  tags = local.common_tags
}

resource "azurerm_network_interface" "utility" {
  name                = "nic-hmlb-util"
  location            = azurerm_resource_group.utility.location
  resource_group_name = azurerm_resource_group.utility.name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.utility.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.utility.id
  }

  tags = local.common_tags
}

resource "azurerm_network_security_rule" "https" {
  name                        = "allow-https"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.utility.name
  network_security_group_name = azurerm_network_security_group.utility.name
}

resource "azurerm_network_security_rule" "http" {
  name                        = "allow-http"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.utility.name
  network_security_group_name = azurerm_network_security_group.utility.name
}

