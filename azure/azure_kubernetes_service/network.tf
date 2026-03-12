resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "${var.environment}-integration-app-private-endpoints-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowAKSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["6379", "6380"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}
