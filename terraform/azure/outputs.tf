output "utility_public_ip" {
  description = "Public IP address of the utility VM"
  value       = azurerm_public_ip.utility.ip_address
}

output "utility_private_ip" {
  description = "Private IP address assigned to the utility NIC"
  value       = azurerm_network_interface.utility.private_ip_address
}

output "utility_vm_name" {
  description = "Azure utility VM name"
  value       = azurerm_linux_virtual_machine.utility.name
}
