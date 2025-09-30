resource "azurerm_cosmosdb_account" "main" {
  count = var.enable_managed_database ? 1 : 0
  name                = "${var.environment}-integration-app-cosmos"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  capabilities {
    name = "EnableMongo"
  }

  capabilities {
    name = "mongoEnableDocLevelTTL"
  }

  capabilities {
    name = "MongoDBv3.4"
  }

  capabilities {
    name = "EnableAggregationPipeline"
  }

  capabilities {
    name = "EnableUniqueCompoundNestedDocs"
  }

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  mongo_server_version = "7.0"

  is_virtual_network_filter_enabled = false
  public_network_access_enabled     = true

  ip_range_filter = []

  # Configure backup policy
  backup {
    type                = "Periodic"
    interval_in_minutes = 240
    retention_in_hours  = 8
    storage_redundancy  = "Local"
  }

  tags = local.common_tags
}

# Cosmos DB MongoDB Database with provisioned throughput
resource "azurerm_cosmosdb_mongo_database" "main" {
  count = var.enable_managed_database ? 1 : 0
  name                = "integration-app"
  resource_group_name = azurerm_cosmosdb_account.main[0].resource_group_name
  account_name        = azurerm_cosmosdb_account.main[0].name

  throughput = 400
}

# Private endpoint for CosmosDB
resource "azurerm_private_endpoint" "cosmosdb" {
  count = var.enable_managed_database ? 1 : 0
  name                = "${var.environment}-integration-app-cosmos-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "${var.environment}-integration-app-cosmos-psce"
    private_connection_resource_id = azurerm_cosmosdb_account.main[0].id
    subresource_names              = ["MongoDB"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "cosmosdb-dns-zone-group"
    private_dns_zone_ids = var.enable_managed_database ? [azurerm_private_dns_zone.cosmosdb[0].id] : []
  }

  tags = local.common_tags
}

# Private DNS zone for CosmosDB
resource "azurerm_private_dns_zone" "cosmosdb" {
  count = var.enable_managed_database ? 1 : 0
  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = var.resource_group_name

  tags = local.common_tags
}

# Link private DNS zone to AKS VNet
resource "azurerm_private_dns_zone_virtual_network_link" "cosmosdb" {
  count = var.enable_managed_database ? 1 : 0
  name                  = "${var.environment}-integration-app-cosmos-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmosdb[0].name
  virtual_network_id    = data.azurerm_virtual_network.aks_vnet.id
  registration_enabled  = false

  tags = local.common_tags
}
