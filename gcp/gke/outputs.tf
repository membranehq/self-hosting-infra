# Storage bucket outputs
output "tmp_bucket_name" {
  description = "Name of the temporary files bucket"
  value       = google_storage_bucket.tmp.name
}

output "connectors_bucket_name" {
  description = "Name of the connectors bucket"
  value       = google_storage_bucket.connectors.name
}

output "static_bucket_name" {
  description = "Name of the static content bucket"
  value       = google_storage_bucket.static.name
}

output "static_bucket_url" {
  description = "URL of the static content bucket"
  value       = google_storage_bucket.static.url
}

# CDN outputs
output "cdn_ip_address" {
  description = "The IP address of the CDN"
  value       = var.enable_cdn ? google_compute_global_address.cdn_ip[0].address : null
}

output "cdn_static_url" {
  description = "The URL for static content via CDN"
  value       = var.enable_cdn ? "https://static.${var.domain_name}" : null
}

# DNS outputs
output "dns_zone_name" {
  description = "The name of the DNS zone"
  value       = google_dns_managed_zone.main.name
}

output "domain_name" {
  description = "Domain name"
  value       = var.domain_name
}

output "dns_name_servers" {
  description = "The name servers for the DNS zone"
  value       = google_dns_managed_zone.main.name_servers
}

# Redis outputs
output "redis_host" {
  description = "The IP address of the Redis instance"
  value       = google_redis_instance.cache.host
}

output "redis_port" {
  description = "The port of the Redis instance"
  value       = google_redis_instance.cache.port
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = var.redis_tier == "STANDARD_HA" ? "redis://:${google_redis_instance.cache.auth_string}@${google_redis_instance.cache.host}:${google_redis_instance.cache.port}" : "redis://${google_redis_instance.cache.host}:${google_redis_instance.cache.port}"
  sensitive   = true
}

output "redis_auth_string" {
  description = "Redis authentication string (only for STANDARD_HA tier)"
  value       = var.redis_tier == "STANDARD_HA" ? google_redis_instance.cache.auth_string : "No auth (BASIC tier)"
  sensitive   = true
}

# External DNS service account email
output "external_dns_service_account_email" {
  description = "Email of the External DNS service account"
  value       = google_service_account.external_dns.email
}

output "gcp_project_id" {
  description = "GCP project ID"
  value       = var.gcp_project_id
}
