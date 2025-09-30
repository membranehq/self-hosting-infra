resource "azurerm_redis_cache" "main" {
  name                 = "${var.environment}-integration-app-redis"
  location             = var.location
  resource_group_name  = var.resource_group_name
  capacity             = 1
  family               = "C"
  sku_name             = "Standard"
  minimum_tls_version  = "1.2"
  non_ssl_port_enabled = true

  # Enable both public and private access
  public_network_access_enabled = true

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = local.common_tags
}

# Private endpoint for Redis
resource "azurerm_private_endpoint" "redis" {
  name                = "${var.environment}-integration-app-redis-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.environment}-integration-app-redis-psce"
    private_connection_resource_id = azurerm_redis_cache.main.id
    subresource_names              = ["redisCache"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "redis-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.redis.id]
  }

  tags = local.common_tags
}

# Private DNS zone for Redis
resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redis.cache.windows.net"
  resource_group_name = var.resource_group_name

  tags = local.common_tags
}

# Link private DNS zone to AKS VNet
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${var.environment}-integration-app-redis-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false

  tags = local.common_tags
}