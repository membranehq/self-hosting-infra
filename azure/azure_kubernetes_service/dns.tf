resource "azurerm_dns_txt_record" "afd_static_validation" {
  name                = "_dnsauth.static"
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.static.validation_token
  }
}

resource "azurerm_dns_cname_record" "static" {
  name                = "static"
  zone_name           = var.dns_zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.static.host_name
}
