# Cosmos DB Account with MongoDB API
resource "azurerm_cosmosdb_account" "main" {
  name                = "${var.environment}-integration-app-cosmos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
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

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 10
    max_staleness_prefix    = 200
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  mongo_server_version = "4.2"

  is_virtual_network_filter_enabled = false

  # Temporarily disable IP filtering to allow all connections
  # ip_range_filter = []

  tags = local.common_tags
}

# Cosmos DB MongoDB Database
resource "azurerm_cosmosdb_mongo_database" "main" {
  name                = "integration-app"
  resource_group_name = azurerm_cosmosdb_account.main.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

# Random password for Cosmos DB
resource "random_password" "cosmosdb_password" {
  length  = 30
  special = false
}