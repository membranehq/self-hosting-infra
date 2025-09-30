# Reserve a global static IP for the load balancer
resource "google_compute_global_address" "cdn_ip" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-ip"
  project = var.gcp_project_id
}

# Backend bucket for serving static content
resource "google_compute_backend_bucket" "static_backend" {
  count = var.enable_cdn ? 1 : 0

  name        = "${var.project}-${var.environment}-static-backend"
  description = "Backend bucket for static content"
  bucket_name = google_storage_bucket.static.name
  project     = var.gcp_project_id

  # Enable CDN
  enable_cdn = true

  # CDN policy
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"

    # Cache TTLs
    client_ttl  = 3600
    default_ttl = 3600
    max_ttl     = 86400

    # Negative caching
    negative_caching = true
    negative_caching_policy {
      code = 404
      ttl  = 120
    }

    # Cache key policy
    cache_key_policy {
      query_string_whitelist = []
    }
  }

  # Compression
  compression_mode = "AUTOMATIC"
}

# URL map for routing
resource "google_compute_url_map" "cdn_url_map" {
  count = var.enable_cdn ? 1 : 0

  name            = "${var.project}-${var.environment}-cdn-url-map"
  default_service = google_compute_backend_bucket.static_backend[0].id
  project         = var.gcp_project_id

  # Host rules for custom domains
  host_rule {
    hosts        = ["static.${var.domain_name}"]
    path_matcher = "static-paths"
  }

  # Path matchers
  path_matcher {
    name            = "static-paths"
    default_service = google_compute_backend_bucket.static_backend[0].id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_bucket.static_backend[0].id
      route_action {
        url_rewrite {
          path_prefix_rewrite = "/"
        }
      }
    }
  }
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "cdn_cert" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-cert"
  project = var.gcp_project_id

  managed {
    domains = ["static.${var.domain_name}"]
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "cdn_https_proxy" {
  count = var.enable_cdn ? 1 : 0

  name             = "${var.project}-${var.environment}-cdn-https-proxy"
  url_map          = google_compute_url_map.cdn_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.cdn_cert[0].id]
  project          = var.gcp_project_id
}

# HTTP proxy (for redirect to HTTPS)
resource "google_compute_target_http_proxy" "cdn_http_proxy" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-http-proxy"
  url_map = google_compute_url_map.cdn_http_redirect[0].id
  project = var.gcp_project_id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "cdn_http_redirect" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-http-redirect"
  project = var.gcp_project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "cdn_https_forwarding" {
  count = var.enable_cdn ? 1 : 0

  name                  = "${var.project}-${var.environment}-cdn-https-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.cdn_https_proxy[0].id
  ip_address            = google_compute_global_address.cdn_ip[0].id
  project               = var.gcp_project_id
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "cdn_http_forwarding" {
  count = var.enable_cdn ? 1 : 0

  name                  = "${var.project}-${var.environment}-cdn-http-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.cdn_http_proxy[0].id
  ip_address            = google_compute_global_address.cdn_ip[0].id
  project               = var.gcp_project_id
}

# Cloud Armor security policy (optional, for DDoS protection)
resource "google_compute_security_policy" "cdn_security_policy" {
  count = var.enable_cdn && var.environment == "prod" ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-security-policy"
  project = var.gcp_project_id

  # Default rule
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule, allow all traffic"
  }

  # Rate limiting rule
  rule {
    action   = "rate_based_ban"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 1000
        interval_sec = 60
      }
    }
    description = "Rate limit rule"
  }
}