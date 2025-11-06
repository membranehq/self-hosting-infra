# Single Storage Account for all storage needs
resource "azurerm_storage_account" "main" {
  name                             = "${var.environment}${var.project}storagesta"
  resource_group_name              = azurerm_resource_group.main.name
  location                         = azurerm_resource_group.main.location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = true


  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3000
    }
  }

  tags = local.common_tags
}

# Container for temporary files
resource "azurerm_storage_container" "tmp" {
  name                  = "${var.environment}-${var.project}-temp-container"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Container for connectors
resource "azurerm_storage_container" "connectors" {
  name                  = "${var.environment}-${var.project}-connectors-container"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Container for copilot
resource "azurerm_storage_container" "copilot" {
  name                  = "${var.environment}-${var.project}-copilot-container"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Note: For static website hosting, Azure automatically creates a $web container
# We'll use that container for static files instead of creating a separate one

# Static website configuration
resource "azurerm_storage_account_static_website" "main" {
  storage_account_id = azurerm_storage_account.main.id
  index_document     = "index.html"
  error_404_document = "404.html"
}

# Role assignment to allow Container App to access Storage Account
# Note: These require User Access Administrator or Owner permissions to create via Terraform
# The managed identity principal_id is: ce4b1a49-f429-4ff2-ac39-2f50fe680789
# Manual assignment required via Azure Portal or Azure CLI with elevated permissions:
#
# az role assignment create \
#   --assignee <principal-id> \
#   --role "Storage Blob Data Contributor" \
#   --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account>"
#
# az role assignment create \
#   --assignee <principal-id> \
#   --role "Storage Account Contributor" \
#   --scope "/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Storage/storageAccounts/<storage-account>"

# Role assignments commented out due to insufficient permissions
# Uncomment these after granting User Access Administrator or Owner role to your service principal
resource "azurerm_role_assignment" "api_storage_blob_data_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_container_app.api.identity.0.principal_id
  depends_on           = [azurerm_container_app.api]
}

resource "azurerm_role_assignment" "api_storage_account_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_container_app.api.identity.0.principal_id
  depends_on           = [azurerm_container_app.api]
}

# Lifecycle management for tmp container
resource "azurerm_storage_management_policy" "tmp" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "cleanup"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["tmp/"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}
