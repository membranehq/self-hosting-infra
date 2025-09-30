resource "google_redis_instance" "cache" {
  name           = "${var.project}-${var.environment}-redis"
  tier           = var.redis_tier
  memory_size_gb = var.redis_memory_size_gb
  region         = var.gcp_region

  authorized_network = data.google_compute_network.vpc.id

  redis_version = var.redis_version
  display_name  = "${var.project}-${var.environment} Redis Cache"

  # Auth is only supported on STANDARD_HA tier
  auth_enabled = var.redis_tier == "STANDARD_HA" ? true : false

  labels = local.common_labels

  lifecycle {
    prevent_destroy = true
  }
}


data "google_compute_network" "vpc" {
  name = var.vpc_name
}
