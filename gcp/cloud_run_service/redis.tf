# Google Cloud Memorystore for Redis
resource "google_redis_instance" "main" {
  name               = "${local.service_name_prefix}-redis"
  tier               = var.redis_tier
  memory_size_gb     = var.redis_memory_size_gb
  region             = var.region
  redis_version      = var.redis_version
  auth_enabled       = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"

  authorized_network = google_compute_network.main.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  redis_configs = {
    maxmemory-policy = "allkeys-lru"
  }

  labels = local.common_labels

  depends_on = [google_service_networking_connection.private_vpc_connection]
}
