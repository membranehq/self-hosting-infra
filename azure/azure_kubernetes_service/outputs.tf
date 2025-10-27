output "tmp_bucket_name" {
  value = azurerm_storage_container.tmp.name
}

output "connectors_bucket_name" {
  value = azurerm_storage_container.connectors.name
}

# Private Redis URI (for services in AKS cluster) - uses hostname with non-SSL for private network
# output "redis_uri_private" {
#   value     = "redis://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_private_endpoint.redis.private_service_connection[0].private_ip_address}:${azurerm_redis_cache.main.port}"
#   sensitive = true
# }

output "redis_uri" {
  value     = "rediss://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_redis_cache.main.hostname}:${azurerm_redis_cache.main.ssl_port}"
  sensitive = true
}

output "static_uri" {
  value = "https://${azurerm_cdn_frontdoor_custom_domain.static.host_name}"
}

output "storage_connection_string" {
  value     = azurerm_storage_account.main.primary_connection_string
  sensitive = true
}

output "external_dns_identity_client_id" {
  value       = azurerm_user_assigned_identity.external_dns.client_id
  description = "Client ID of the managed identity for External-DNS"
}

output "external_dns_identity_resource_id" {
  value       = azurerm_user_assigned_identity.external_dns.id
  description = "Resource ID of the managed identity for External-DNS"
}

output "dns_zone_name" {
  value       = var.dns_zone_name
  description = "DNS zone name for External-DNS domain filter"
}

output "resource_group_name" {
  value       = var.resource_group_name
  description = "Resource group name where DNS zone is located"
}

output "tenant_id" {
  value       = data.azurerm_client_config.current.tenant_id
  description = "Azure tenant ID for External-DNS authentication"
}