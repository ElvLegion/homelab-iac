data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "bootstrap" {
  name                = "id-hmlb-util-bootstrap"
  location            = local.location
  resource_group_name = azurerm_resource_group.utility.name

  tags = local.common_tags
}

resource "azurerm_key_vault" "bootstrap" {
  name                = "kv-hmlb-${substr(md5(var.subscription_id), 0, 8)}"
  location            = local.location
  resource_group_name = azurerm_resource_group.utility.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true

  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.common_tags
}

resource "azurerm_role_assignment" "bootstrap_secret_reader" {
  scope                = azurerm_key_vault.bootstrap.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.bootstrap.principal_id
}
