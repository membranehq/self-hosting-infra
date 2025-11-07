# Cloud DNS Zone
resource "google_dns_managed_zone" "main" {
  name        = "${var.environment}-${var.project}-zone"
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.environment} environment"

  labels = local.common_labels
}

# A Records pointing to Load Balancer IPs
resource "google_dns_record_set" "api" {
  name         = "${local.api_hostname}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.api.address]
}

resource "google_dns_record_set" "ui" {
  name         = "${local.ui_hostname}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.ui.address]
}

resource "google_dns_record_set" "console" {
  name         = "${local.console_hostname}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.console.address]
}

resource "google_dns_record_set" "static" {
  name         = "${local.static_hostname}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.main.name
  rrdatas      = [google_compute_global_address.static.address]
}
