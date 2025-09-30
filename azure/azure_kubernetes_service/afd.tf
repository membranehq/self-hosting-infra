resource "azurerm_cdn_frontdoor_profile" "static" {
  name                = "${var.environment}-afd-static"
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"

  tags = {
    Service = "core-azure"
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "static" {
  name                     = "${var.environment}-afd-static-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id
}

resource "azurerm_cdn_frontdoor_origin_group" "static" {
  name                     = "${var.environment}-afd-static-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "static" {
  name                           = "${var.environment}-afd-static-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.static.id
  enabled                        = true
  host_name                      = "${azurerm_storage_account.main.name}.z13.web.core.windows.net"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "${azurerm_storage_account.main.name}.z13.web.core.windows.net"
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "static" {
  name                            = "${var.environment}-afd-static-route"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.static.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.static.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.static.id]
  enabled                         = true
  forwarding_protocol             = "HttpsOnly"
  https_redirect_enabled          = true
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  link_to_default_domain          = true
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.static.id]
  cdn_frontdoor_rule_set_ids      = [azurerm_cdn_frontdoor_rule_set.static.id]
}

resource "azurerm_cdn_frontdoor_custom_domain" "static" {
  name                     = "staticazureintmembrane"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id
  host_name                = "static.${var.dns_zone_name}"

  tls {
    certificate_type = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "static" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.static.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.static.id]
}

resource "azurerm_cdn_frontdoor_rule_set" "static" {
  name                     = "${var.environment}staticrules"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.static.id
}

resource "azurerm_cdn_frontdoor_rule" "compression" {
  name                      = "enablecompression"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.static.id
  order                     = 1
  behavior_on_match         = "Continue"

  conditions {
    request_method_condition {
      match_values     = ["GET"]
      operator         = "Equal"
      negate_condition = false
    }
  }

  actions {
    route_configuration_override_action {
      compression_enabled           = true
      cache_behavior                = "OverrideIfOriginMissing"
      cache_duration                = "1.00:00:00" # 1 day
      query_string_caching_behavior = "IgnoreQueryString"
    }
  }
}

resource "azurerm_cdn_frontdoor_rule" "cache_static_assets" {
  name                      = "cachestaticassets"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.static.id
  order                     = 2
  behavior_on_match         = "Continue"

  conditions {
    request_uri_condition {
      match_values     = ["*.js", "*.css", "*.png", "*.jpg", "*.jpeg", "*.gif", "*.svg", "*.ico", "*.woff", "*.woff2"]
      operator         = "EndsWith"
      negate_condition = false
    }
  }

  actions {
    route_configuration_override_action {
      cache_behavior                = "OverrideAlways"
      cache_duration                = "7.00:00:00" # 7 days for static assets
      query_string_caching_behavior = "IgnoreQueryString"
    }
  }
}
