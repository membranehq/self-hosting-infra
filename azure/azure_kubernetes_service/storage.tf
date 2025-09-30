resource "azurerm_storage_account" "main" {
  name                             = "${var.environment}integrationapp"
  resource_group_name              = var.resource_group_name
  location                         = var.location
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
  name                  = "integration-app-${var.environment}-temp"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# Container for connectors
resource "azurerm_storage_container" "connectors" {
  name                  = "integration-app-${var.environment}-connectors"
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