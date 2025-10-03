# Azure Resources

This guide covers Azure-specific resource provisioning for Membrane.

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI configured (optional, for manual setup)
- Terraform installed (recommended for infrastructure as code)

## Overview

Required Azure resources:
- **Azure Blob Storage** - Storage for temp files, connectors, and static assets
- **Azure Front Door** - CDN for serving static files (optional)
- **Azure Cache for Redis** - Caching and job queue
- **MongoDB Atlas** - Database (see [Cloud Resources](index.md#mongodb-atlas-setup-terraform-example))

## Azure Blob Storage

### Storage Account and Containers

```hcl
# Variables
variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "resource_group_name" {
  description = "Azure resource group name"
  type        = string
}

variable "resource_group_location" {
  description = "Azure region (e.g., eastus, westeurope)"
  type        = string
}

locals {
  common_tags = {
    Environment = var.environment
    Service     = "membrane"
    ManagedBy   = "terraform"
  }
}

# Storage account
resource "azurerm_storage_account" "main" {
  name                             = "${var.environment}integrationapp"  # Must be globally unique, 3-24 lowercase alphanumeric
  resource_group_name              = var.resource_group_name
  location                         = var.resource_group_location
  account_tier                     = "Standard"
  account_replication_type         = "LRS"  # Use GRS for production
  min_tls_version                  = "TLS1_2"
  cross_tenant_replication_enabled = true
  enable_https_traffic_only        = true

  # CORS configuration for static files
  blob_properties {
    cors_rule {
      allowed_headers    = ["*"]
      allowed_methods    = ["GET", "HEAD"]
      allowed_origins    = ["*"]
      exposed_headers    = ["*"]
      max_age_in_seconds = 3600
    }
  }

  tags = local.common_tags
}

# Container for temporary files
resource "azurerm_storage_container" "tmp" {
  name                  = "integration-app-${var.environment}-tmp"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Container for connectors
resource "azurerm_storage_container" "connectors" {
  name                  = "integration-app-${var.environment}-connectors"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# Static website configuration
# Note: Azure automatically creates a $web container for static websites
resource "azurerm_storage_account_static_website" "main" {
  storage_account_id = azurerm_storage_account.main.id
  index_document     = "index.html"
  error_404_document = "404.html"
}

# Lifecycle management for tmp container
resource "azurerm_storage_management_policy" "tmp" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "cleanup-old-files"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["integration-app-${var.environment}-tmp/"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}

# Output storage connection string (for non-managed identity scenarios)
output "storage_connection_string" {
  value     = azurerm_storage_account.main.primary_connection_string
  sensitive = true
  description = "Storage account connection string"
}

# Output storage account name and key
output "storage_account_name" {
  value       = azurerm_storage_account.main.name
  description = "Storage account name"
}

output "storage_account_key" {
  value     = azurerm_storage_account.main.primary_access_key
  sensitive = true
  description = "Storage account primary access key"
}

# Output static website URL
output "static_website_url" {
  value       = azurerm_storage_account.main.primary_web_endpoint
  description = "Static website endpoint"
}
```

## Azure Front Door (Optional CDN)

Azure Front Door provides CDN capabilities with custom domains and SSL.

### Front Door Configuration

```hcl
variable "dns_zone_name" {
  description = "DNS zone name for custom domain (e.g., example.com)"
  type        = string
}

# Front Door profile
resource "azurerm_cdn_frontdoor_profile" "static" {
  name                = "${var.environment}-afd-static"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"

  tags = local.common_tags
}

# Front Door endpoint
resource "azurerm_cdn_frontdoor_endpoint" "static" {
  name                     = "${var.environment}-afd-static-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id

  tags = local.common_tags
}

# Origin group
resource "azurerm_cdn_frontdoor_origin_group" "static" {
  name                     = "${var.environment}-afd-static-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    interval_in_seconds = 100
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

# Origin (static website endpoint)
resource "azurerm_cdn_frontdoor_origin" "static" {
  name                          = "${var.environment}-afd-static-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.static.id
  enabled                       = true

  # Use the blob storage static website endpoint
  host_name                      = replace(replace(azurerm_storage_account.main.primary_web_endpoint, "https://", ""), "/", "")
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = replace(replace(azurerm_storage_account.main.primary_web_endpoint, "https://", ""), "/", "")
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# Custom domain
resource "azurerm_cdn_frontdoor_custom_domain" "static" {
  name                     = replace("static-${var.dns_zone_name}", ".", "-")
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id
  host_name                = "static.${var.dns_zone_name}"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

# Rule set for caching and compression
resource "azurerm_cdn_frontdoor_rule_set" "static" {
  name                     = "${var.environment}staticrules"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id
}

# Enable compression rule
resource "azurerm_cdn_frontdoor_rule" "compression" {
  name                      = "enablecompression"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.static.id
  order                     = 1
  behavior_on_match         = "Continue"

  conditions {
    request_method_condition {
      match_values     = ["GET", "HEAD"]
      operator         = "Equal"
      negate_condition = false
    }
  }

  actions {
    route_configuration_override_action {
      compression_enabled           = true
      cache_behavior                = "OverrideIfOriginMissing"
      cache_duration                = "1.00:00:00"  # 1 day
      query_string_caching_behavior = "IgnoreQueryString"
    }
  }
}

# Cache static assets rule
resource "azurerm_cdn_frontdoor_rule" "cache_static_assets" {
  name                      = "cachestaticassets"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.static.id
  order                     = 2
  behavior_on_match         = "Continue"

  conditions {
    url_file_extension_condition {
      match_values     = ["js", "css", "png", "jpg", "jpeg", "gif", "svg", "ico", "woff", "woff2", "ttf", "eot"]
      operator         = "Equal"
      negate_condition = false
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior                = "OverrideAlways"
      cache_duration                = "7.00:00:00"  # 7 days
      query_string_caching_behavior = "IgnoreQueryString"
    }
  }
}

# Route configuration
resource "azurerm_cdn_frontdoor_route" "static" {
  name                          = "${var.environment}-afd-static-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.static.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.static.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.static.id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain          = true
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.static.id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.static.id]
}

# Associate custom domain with route
resource "azurerm_cdn_frontdoor_custom_domain_association" "static" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.static.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.static.id]
}
```

### DNS Configuration

```hcl
# DNS zone (if managing DNS in Azure)
data "azurerm_dns_zone" "main" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
}

# TXT record for Front Door domain validation
resource "azurerm_dns_txt_record" "afd_static_validation" {
  name                = "_dnsauth.static"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.static.validation_token
  }

  tags = local.common_tags
}

# CNAME record pointing to Front Door endpoint
resource "azurerm_dns_cname_record" "static" {
  name                = "static"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.static.host_name

  tags = local.common_tags
}

# Output Front Door URL
output "frontdoor_static_url" {
  value       = "https://${azurerm_cdn_frontdoor_endpoint.static.host_name}"
  description = "Front Door endpoint URL for static files"
}

output "frontdoor_custom_domain_url" {
  value       = "https://static.${var.dns_zone_name}"
  description = "Custom domain URL for static files (use for BASE_STATIC_URI)"
}
```

## Redis

### Azure Cache for Redis

```hcl
# Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  name                = "${var.environment}-membrane-redis"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  capacity            = 1  # 0-6 for Basic/Standard, 1-5 for Premium
  family              = "C"  # C for Basic/Standard, P for Premium
  sku_name            = "Standard"  # Basic, Standard, or Premium

  # Redis version
  redis_version = "6"

  # Enable non-SSL port (optional - not recommended for production)
  enable_non_ssl_port = false

  # Minimum TLS version
  minimum_tls_version = "1.2"

  # Redis configuration
  redis_configuration {
    # No persistence needed - Membrane uses Redis as cache only
    rdb_backup_enabled = false
  }

  # Patch schedule (optional)
  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 5
  }

  tags = local.common_tags
}

# Output Redis connection details
output "redis_hostname" {
  value       = azurerm_redis_cache.main.hostname
  description = "Redis hostname"
}

output "redis_ssl_port" {
  value       = azurerm_redis_cache.main.ssl_port
  description = "Redis SSL port"
}

output "redis_primary_key" {
  value     = azurerm_redis_cache.main.primary_access_key
  sensitive = true
  description = "Redis primary access key"
}

output "redis_connection_string" {
  value = format(
    "rediss://:%s@%s:%d",
    azurerm_redis_cache.main.primary_access_key,
    azurerm_redis_cache.main.hostname,
    azurerm_redis_cache.main.ssl_port
  )
  sensitive   = true
  description = "Redis connection string (use for REDIS_URI)"
}
```

### Redis with Private Endpoint (Production)

For production deployments, use a private endpoint:

```hcl
# Premium tier required for private endpoints
resource "azurerm_redis_cache" "main_premium" {
  name                = "${var.environment}-membrane-redis"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  capacity            = 1
  family              = "P"
  sku_name            = "Premium"
  redis_version       = "6"
  minimum_tls_version = "1.2"

  redis_configuration {}

  tags = local.common_tags
}

# Private endpoint
resource "azurerm_private_endpoint" "redis" {
  name                = "${var.environment}-redis-pe"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.environment}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.main_premium.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  tags = local.common_tags
}
```

## Managed Identity (Recommended for Azure)

For Azure deployments, use Managed Identity instead of connection strings.

### System-Assigned Managed Identity

```hcl
# Example for Azure Container Apps
resource "azurerm_container_app" "api" {
  name                         = "${var.environment}-membrane-api"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = var.container_app_environment_id
  revision_mode                = "Single"

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  # ... other configuration ...
}

# Grant Storage Blob Data Contributor role
resource "azurerm_role_assignment" "api_storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_container_app.api.identity[0].principal_id
}
```

### Using Managed Identity

When using Managed Identity, configure these environment variables:

```bash
STORAGE_PROVIDER=abs
AZURE_STORAGE_ACCOUNT_NAME=<storage-account-name>
# Omit AZURE_STORAGE_ACCOUNT_KEY and AZURE_STORAGE_CONNECTION_STRING
```

The Azure SDK will automatically use Managed Identity for authentication.

## MongoDB

**Azure Cosmos DB (MongoDB API) is NOT supported** due to MongoDB API compatibility issues.

**Recommended:** Use [MongoDB Atlas](index.md#mongodb-atlas-setup-terraform-example) (managed service) or self-host MongoDB on Azure VMs.

## Environment Variables Summary

After provisioning Azure resources, configure these environment variables:

```bash
# Storage
STORAGE_PROVIDER=abs
AZURE_STORAGE_ACCOUNT_NAME=prodintegrationapp
AZURE_STORAGE_ACCOUNT_KEY=<storage-account-key>
# OR use connection string:
# AZURE_STORAGE_CONNECTION_STRING=<connection-string>

# Bucket/Container names
TMP_STORAGE_BUCKET=integration-app-prod-tmp
CONNECTORS_STORAGE_BUCKET=integration-app-prod-connectors
STATIC_STORAGE_BUCKET=$web  # Special container for static websites
BASE_STATIC_URI=https://static.example.com

# Redis
REDIS_URI=rediss://:<primary-key>@<hostname>:6380

# MongoDB (from Atlas)
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/membrane
```

## Next Steps

1. Verify all resources are provisioned correctly
2. Configure [Authentication](../authentication/auth0.md)
3. Proceed to [Deployment](../deployment/services.md)
