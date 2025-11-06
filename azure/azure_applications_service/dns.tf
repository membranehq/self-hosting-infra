resource "azurerm_dns_zone" "main" {
  name                = var.domain_name
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Static validation record
resource "azurerm_dns_txt_record" "afd_static_validation" {
  name                = "_dnsauth.static${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.static.validation_token
  }
}

# API validation record
resource "azurerm_dns_txt_record" "afd_api_validation" {
  name                = "_dnsauth.api${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.api.validation_token
  }
}

# UI validation record
resource "azurerm_dns_txt_record" "afd_ui_validation" {
  name                = "_dnsauth.ui${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.ui.validation_token
  }
}

# Console validation record
resource "azurerm_dns_txt_record" "afd_console_validation" {
  name                = "_dnsauth.console${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.console.validation_token
  }
}

# CNAME Records
resource "azurerm_dns_cname_record" "static" {
  name                = "static${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.static.host_name

  depends_on = [azurerm_cdn_frontdoor_custom_domain.static]
}

resource "azurerm_dns_cname_record" "api" {
  name                = "api${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.api.host_name

  depends_on = [azurerm_cdn_frontdoor_custom_domain.api]
}

resource "azurerm_dns_cname_record" "ui" {
  name                = "ui${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.ui.host_name

  depends_on = [azurerm_cdn_frontdoor_custom_domain.ui]
}

resource "azurerm_dns_cname_record" "console" {
  name                = "console${var.environment == "prod" ? "" : ".${var.environment}"}"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.console.host_name

  depends_on = [azurerm_cdn_frontdoor_custom_domain.console]
}
