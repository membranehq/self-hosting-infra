# Global IP addresses for Load Balancers
resource "google_compute_global_address" "api" {
  name = "${local.service_name_prefix}-api-ip"
}

resource "google_compute_global_address" "ui" {
  name = "${local.service_name_prefix}-ui-ip"
}

resource "google_compute_global_address" "console" {
  name = "${local.service_name_prefix}-console-ip"
}

resource "google_compute_global_address" "static" {
  name = "${local.service_name_prefix}-static-ip"
}

# SSL Certificates
resource "google_compute_managed_ssl_certificate" "api" {
  name = "${local.service_name_prefix}-api-cert"

  managed {
    domains = [local.api_hostname]
  }
}

resource "google_compute_managed_ssl_certificate" "ui" {
  name = "${local.service_name_prefix}-ui-cert"

  managed {
    domains = [local.ui_hostname]
  }
}

resource "google_compute_managed_ssl_certificate" "console" {
  name = "${local.service_name_prefix}-console-cert"

  managed {
    domains = [local.console_hostname]
  }
}

resource "google_compute_managed_ssl_certificate" "static" {
  name = "${local.service_name_prefix}-static-cert"

  managed {
    domains = [local.static_hostname]
  }
}

# Backend Services - API
resource "google_compute_region_network_endpoint_group" "api" {
  name                  = "${local.service_name_prefix}-api-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.api.name
  }
}

resource "google_compute_backend_service" "api" {
  name                  = "${local.service_name_prefix}-api-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.api.id
  }

  log_config {
    enable = true
  }
}

# Backend Services - UI
resource "google_compute_region_network_endpoint_group" "ui" {
  name                  = "${local.service_name_prefix}-ui-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.ui.name
  }
}

resource "google_compute_backend_service" "ui" {
  name                  = "${local.service_name_prefix}-ui-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.ui.id
  }

  log_config {
    enable = true
  }
}

# Backend Services - Console
resource "google_compute_region_network_endpoint_group" "console" {
  name                  = "${local.service_name_prefix}-console-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.console.name
  }
}

resource "google_compute_backend_service" "console" {
  name                  = "${local.service_name_prefix}-console-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_region_network_endpoint_group.console.id
  }

  log_config {
    enable = true
  }
}

# Backend Bucket for Static Content
resource "google_compute_backend_bucket" "static" {
  name        = "${local.service_name_prefix}-static-backend"
  bucket_name = google_storage_bucket.static.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    client_ttl        = 3600
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
    serve_while_stale = 86400
  }
}

# URL Maps
resource "google_compute_url_map" "api" {
  name            = "${local.service_name_prefix}-api-urlmap"
  default_service = google_compute_backend_service.api.id
}

resource "google_compute_url_map" "ui" {
  name            = "${local.service_name_prefix}-ui-urlmap"
  default_service = google_compute_backend_service.ui.id
}

resource "google_compute_url_map" "console" {
  name            = "${local.service_name_prefix}-console-urlmap"
  default_service = google_compute_backend_service.console.id
}

resource "google_compute_url_map" "static" {
  name            = "${local.service_name_prefix}-static-urlmap"
  default_service = google_compute_backend_bucket.static.id
}

# HTTPS Proxies
resource "google_compute_target_https_proxy" "api" {
  name             = "${local.service_name_prefix}-api-proxy"
  url_map          = google_compute_url_map.api.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api.id]
}

resource "google_compute_target_https_proxy" "ui" {
  name             = "${local.service_name_prefix}-ui-proxy"
  url_map          = google_compute_url_map.ui.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ui.id]
}

resource "google_compute_target_https_proxy" "console" {
  name             = "${local.service_name_prefix}-console-proxy"
  url_map          = google_compute_url_map.console.id
  ssl_certificates = [google_compute_managed_ssl_certificate.console.id]
}

resource "google_compute_target_https_proxy" "static" {
  name             = "${local.service_name_prefix}-static-proxy"
  url_map          = google_compute_url_map.static.id
  ssl_certificates = [google_compute_managed_ssl_certificate.static.id]
}

# HTTP to HTTPS redirect
resource "google_compute_url_map" "https_redirect_api" {
  name = "${local.service_name_prefix}-api-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_url_map" "https_redirect_ui" {
  name = "${local.service_name_prefix}-ui-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_url_map" "https_redirect_console" {
  name = "${local.service_name_prefix}-console-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_url_map" "https_redirect_static" {
  name = "${local.service_name_prefix}-static-https-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# HTTP Proxies for redirect
resource "google_compute_target_http_proxy" "api_redirect" {
  name    = "${local.service_name_prefix}-api-http-proxy"
  url_map = google_compute_url_map.https_redirect_api.id
}

resource "google_compute_target_http_proxy" "ui_redirect" {
  name    = "${local.service_name_prefix}-ui-http-proxy"
  url_map = google_compute_url_map.https_redirect_ui.id
}

resource "google_compute_target_http_proxy" "console_redirect" {
  name    = "${local.service_name_prefix}-console-http-proxy"
  url_map = google_compute_url_map.https_redirect_console.id
}

resource "google_compute_target_http_proxy" "static_redirect" {
  name    = "${local.service_name_prefix}-static-http-proxy"
  url_map = google_compute_url_map.https_redirect_static.id
}

# Forwarding Rules - HTTPS
resource "google_compute_global_forwarding_rule" "api_https" {
  name                  = "${local.service_name_prefix}-api-https"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.api.id
  ip_address            = google_compute_global_address.api.id
}

resource "google_compute_global_forwarding_rule" "ui_https" {
  name                  = "${local.service_name_prefix}-ui-https"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.ui.id
  ip_address            = google_compute_global_address.ui.id
}

resource "google_compute_global_forwarding_rule" "console_https" {
  name                  = "${local.service_name_prefix}-console-https"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.console.id
  ip_address            = google_compute_global_address.console.id
}

resource "google_compute_global_forwarding_rule" "static_https" {
  name                  = "${local.service_name_prefix}-static-https"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.static.id
  ip_address            = google_compute_global_address.static.id
}

# Forwarding Rules - HTTP (redirect to HTTPS)
resource "google_compute_global_forwarding_rule" "api_http" {
  name                  = "${local.service_name_prefix}-api-http"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.api_redirect.id
  ip_address            = google_compute_global_address.api.id
}

resource "google_compute_global_forwarding_rule" "ui_http" {
  name                  = "${local.service_name_prefix}-ui-http"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.ui_redirect.id
  ip_address            = google_compute_global_address.ui.id
}

resource "google_compute_global_forwarding_rule" "console_http" {
  name                  = "${local.service_name_prefix}-console-http"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.console_redirect.id
  ip_address            = google_compute_global_address.console.id
}

resource "google_compute_global_forwarding_rule" "static_http" {
  name                  = "${local.service_name_prefix}-static-http"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.static_redirect.id
  ip_address            = google_compute_global_address.static.id
}
