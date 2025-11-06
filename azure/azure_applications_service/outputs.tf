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
    static  = "https://${local.static_hostname}"
    api     = "https://${local.api_hostname}"
    ui      = "https://${local.ui_hostname}"
    console = "https://${local.console_hostname}"
  }
}

output "container_app_urls" {
  description = "Container App URLs"
  value = {
    api                  = "https://${azurerm_container_app.api.latest_revision_fqdn}"
    ui                   = "https://${azurerm_container_app.ui.latest_revision_fqdn}"
    console              = "https://${azurerm_container_app.console.latest_revision_fqdn}"
    custom_code_runner   = "https://${azurerm_container_app.custom_code_runner.latest_revision_fqdn}"
    instant_tasks_worker = "https://${azurerm_container_app.instant_tasks_worker.latest_revision_fqdn}"
    queued_tasks_worker  = "https://${azurerm_container_app.queued_tasks_worker.latest_revision_fqdn}"
    orchestrator         = "https://${azurerm_container_app.orchestrator.latest_revision_fqdn}"
  }
}

output "dns_zone_name_servers" {
  description = "The name servers for the Azure DNS zone"
  value       = azurerm_dns_zone.main.name_servers
}

# output "redis_hostname" {
#   description = "Redis cache hostname"
#   value       = azurerm_redis_cache.main.hostname
# }

output "redis_hostname" {
  description = "Managed Redis hostname"
  value       = azurerm_managed_redis.managed_redis.hostname
}

output "redis_private_endpoint_ip" {
  description = "Redis Private Endpoint IP Address"
  value       = azurerm_private_endpoint.membrane_redis_pe.private_service_connection[0].private_ip_address
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}
