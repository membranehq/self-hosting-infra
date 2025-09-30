# Create DNS managed zone
resource "google_dns_managed_zone" "main" {
  name        = var.dns_zone_name
  dns_name    = "${var.domain_name}."
  description = "${var.project} ${var.environment} DNS zone"
  project     = var.gcp_project_id

  labels = local.common_labels

  dnssec_config {
    state = "on"
  }
}

# DNS record for static content CDN
resource "google_dns_record_set" "static_cdn" {
  count = var.enable_cdn ? 1 : 0

  name         = "static.${google_dns_managed_zone.main.dns_name}"
  managed_zone = google_dns_managed_zone.main.name
  type         = "A"
  ttl          = 300
  project      = var.gcp_project_id

  rrdatas = [google_compute_global_address.cdn_ip[0].address]
}

# A record for the root domain (optional)
resource "google_dns_record_set" "root" {
  count = var.enable_cdn ? 1 : 0

  name         = google_dns_managed_zone.main.dns_name
  managed_zone = google_dns_managed_zone.main.name
  type         = "A"
  ttl          = 300
  project      = var.gcp_project_id

  rrdatas = [google_compute_global_address.cdn_ip[0].address]
}

# CAA record for SSL certificate issuance
resource "google_dns_record_set" "caa" {
  name         = google_dns_managed_zone.main.dns_name
  managed_zone = google_dns_managed_zone.main.name
  type         = "CAA"
  ttl          = 300
  project      = var.gcp_project_id

  rrdatas = [
    "0 issue \"pki.goog\"",
    "0 issue \"letsencrypt.org\""
  ]
}