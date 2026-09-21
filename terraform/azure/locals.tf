locals {
  location = "centralus"

  common_tags = {
    Environment = "Homelab"
    ManagedBy   = "Terraform"
    Workload    = "Utility"
  }

  bootstrap_cloud_init = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    bootstrap_identity_client_id = azurerm_user_assigned_identity.bootstrap.client_id
    key_vault_name               = azurerm_key_vault.bootstrap.name
    tailscale_hostname           = "vm-hmlb-util"
  })
}
