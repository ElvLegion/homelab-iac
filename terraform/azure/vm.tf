resource "azurerm_linux_virtual_machine" "utility" {
  name                = "vm-hmlb-util"
  resource_group_name = azurerm_resource_group.utility.name
  location            = azurerm_resource_group.utility.location
  size                = "Standard_D2ls_v6"

  admin_username = "elvish"

  network_interface_ids = [
    azurerm_network_interface.utility.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = "elvish"
    public_key = file(pathexpand("~/.ssh/hmlb_azure.pub"))
  }

  os_disk {
    name                 = "disk-hmlb-util-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-26_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}
