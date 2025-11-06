# Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  name                = "${var.environment}-membrane-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 0 # C0 Basic (250MB)
  family              = "C"
  sku_name            = "Basic"
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = local.common_tags
}
