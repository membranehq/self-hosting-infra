resource "azurerm_cdn_frontdoor_profile" "static" {
  name                = "${var.environment}-afd-static"
  resource_group_name = azurerm_resource_group.main.name
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
  host_name                = "static.azure.int-membrane.com"

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

# Application Front Door Profile
resource "azurerm_cdn_frontdoor_profile" "apps" {
  name                = "${var.environment}-afd-apps"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = {
    Service = "core-azure"
  }
}

# API Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "api" {
  name                     = "${var.environment}-afd-api-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id
}

resource "azurerm_cdn_frontdoor_origin_group" "api" {
  name                     = "${var.environment}-afd-api-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "api" {
  name                           = "${var.environment}-afd-api-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.api.id
  enabled                        = true
  host_name                      = "${var.environment}-api.${azurerm_container_app_environment.main.default_domain}"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "${var.environment}-api.${azurerm_container_app_environment.main.default_domain}"
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_custom_domain" "api" {
  name                     = "apiazureintmembrane"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id
  host_name                = "api.azure.int-membrane.com"

  tls {
    certificate_type = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_route" "api" {
  name                            = "${var.environment}-afd-api-route"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.api.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.api.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.api.id]
  enabled                         = true
  forwarding_protocol             = "HttpsOnly"
  https_redirect_enabled          = true
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  link_to_default_domain          = false
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.api.id]
}

# UI Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "ui" {
  name                     = "${var.environment}-afd-ui-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id
}

resource "azurerm_cdn_frontdoor_origin_group" "ui" {
  name                     = "${var.environment}-afd-ui-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "ui" {
  name                           = "${var.environment}-afd-ui-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.ui.id
  enabled                        = true
  host_name                      = "${var.environment}-ui.${azurerm_container_app_environment.main.default_domain}"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "${var.environment}-ui.${azurerm_container_app_environment.main.default_domain}"
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_custom_domain" "ui" {
  name                     = "uiazureintmembrane"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id
  host_name                = "ui.azure.int-membrane.com"

  tls {
    certificate_type = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_route" "ui" {
  name                            = "${var.environment}-afd-ui-route"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.ui.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.ui.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.ui.id]
  enabled                         = true
  forwarding_protocol             = "HttpsOnly"
  https_redirect_enabled          = true
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  link_to_default_domain          = false
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.ui.id]
}

# Console Endpoint
resource "azurerm_cdn_frontdoor_endpoint" "console" {
  name                     = "${var.environment}-afd-console-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id
}

resource "azurerm_cdn_frontdoor_origin_group" "console" {
  name                     = "${var.environment}-afd-console-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "console" {
  name                           = "${var.environment}-afd-console-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.console.id
  enabled                        = true
  host_name                      = "${var.environment}-console.${azurerm_container_app_environment.main.default_domain}"
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = "${var.environment}-console.${azurerm_container_app_environment.main.default_domain}"
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_custom_domain" "console" {
  name                     = "consoleazureintmembrane"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.apps.id
  host_name                = "console.azure.int-membrane.com"

  tls {
    certificate_type = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_route" "console" {
  name                            = "${var.environment}-afd-console-route"
  cdn_frontdoor_endpoint_id       = azurerm_cdn_frontdoor_endpoint.console.id
  cdn_frontdoor_origin_group_id   = azurerm_cdn_frontdoor_origin_group.console.id
  cdn_frontdoor_origin_ids        = [azurerm_cdn_frontdoor_origin.console.id]
  enabled                         = true
  forwarding_protocol             = "HttpsOnly"
  https_redirect_enabled          = true
  patterns_to_match               = ["/*"]
  supported_protocols             = ["Http", "Https"]
  link_to_default_domain          = false
  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.console.id]
}

output "afd_custom_domain_validation_tokens" {
  value = {
    static  = azurerm_cdn_frontdoor_custom_domain.static.validation_token
    api     = azurerm_cdn_frontdoor_custom_domain.api.validation_token
    ui      = azurerm_cdn_frontdoor_custom_domain.ui.validation_token
    console = azurerm_cdn_frontdoor_custom_domain.console.validation_token
  }
  description = "Validation tokens for the custom domains. Add these as TXT records in your DNS if required."
}