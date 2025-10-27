# Azure Key Vault for secrets management
resource "azurerm_key_vault" "main" {
  name                        = "${var.environment}integrationappkv"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = false
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore",
      "Purge"
    ]
  }

  tags = local.common_tags
}

# Store secrets in Key Vault
resource "azurerm_key_vault_secret" "jwt_secret" {
  name         = "jwt-secret"
  value        = random_password.secret.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
}

resource "azurerm_key_vault_secret" "encryption_secret" {
  name         = "encryption-secret"
  value        = random_password.encryption_secret.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
}

resource "azurerm_key_vault_secret" "harbor_credentials" {
  name = "harbor-credentials"
  value = jsonencode({
    username = var.harbor_username
    password = var.harbor_password
  })
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault.main]
}