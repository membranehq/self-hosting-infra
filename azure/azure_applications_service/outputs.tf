output "storage_connection_string" {
  description = "The primary connection string for the storage account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "storage_account_key" {
  description = "The primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "static_website_url" {
  description = "The URL of the static website"
  value       = azurerm_storage_account.main.primary_web_host
}

output "afd_endpoint_urls" {
  description = "Azure Front Door endpoint URLs"
  value = {
    static  = "https://${azurerm_cdn_frontdoor_endpoint.static.host_name}"
    api     = "https://${azurerm_cdn_frontdoor_endpoint.api.host_name}"
    ui      = "https://${azurerm_cdn_frontdoor_endpoint.ui.host_name}"
    console = "https://${azurerm_cdn_frontdoor_endpoint.console.host_name}"
  }
}

output "custom_domain_urls" {
  description = "The custom domain URLs"
  value = {
    static  = "https://static.azure.int-membrane.com"
    api     = "https://api.azure.int-membrane.com"
    ui      = "https://ui.azure.int-membrane.com"
    console = "https://console.azure.int-membrane.com"
  }
}

output "container_app_urls" {
  description = "Container App URLs"
  value = {
    api                = "https://${azurerm_container_app.api.latest_revision_fqdn}"
    ui                 = "https://${azurerm_container_app.ui.latest_revision_fqdn}"
    console            = "https://${azurerm_container_app.console.latest_revision_fqdn}"
    custom_code_runner = "https://${azurerm_container_app.custom_code_runner.latest_revision_fqdn}"
  }
}

output "dns_zone_name_servers" {
  description = "The name servers for the Azure DNS zone"
  value       = azurerm_dns_zone.main.name_servers
}

output "cosmosdb_endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = azurerm_redis_cache.main.hostname
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}
