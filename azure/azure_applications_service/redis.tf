# Azure Cache for Redis (Legacy - commented out in favor of Managed Redis)
# resource "azurerm_redis_cache" "main" {
#   name                = "${var.environment}-${var.project}-cache-redis"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   capacity            = 0 # C0 Basic (250MB)
#   family              = "C"
#   sku_name            = "Basic"
#   minimum_tls_version = "1.2"
#
#   redis_configuration {
#     maxmemory_policy = "allkeys-lru"
#   }
#
#   tags = local.common_tags
# }

resource "azurerm_managed_redis" "managed_redis" {
  name                = "${var.environment}-${var.project}-azure-menaged-redis"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "Balanced_B0"

  default_database {
    access_keys_authentication_enabled = true
    client_protocol                    = "Encrypted"
    clustering_policy                  = "EnterpriseCluster"
    eviction_policy                    = "NoEviction"

  }

  tags = local.common_tags
}
