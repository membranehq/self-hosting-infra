data "azurerm_virtual_network" "aks_vnet" {
  name                = var.aks_vnet_name != null ? var.aks_vnet_name : "aks-vnet-${var.aks_cluster_name}"
  resource_group_name = var.resource_group_name
}


# Calculate next available subnet CIDR dynamically
locals {
  # Get VNet address space (use first one if multiple)
  vnet_address_space = data.azurerm_virtual_network.aks_vnet.address_space[0]

  # Calculate next available /24 subnet
  # Using a higher offset (100) to avoid conflicts with existing subnets
  calculated_subnet_cidr = cidrsubnet(local.vnet_address_space, 8, 100)

  # Use provided CIDR or calculated one
  private_endpoint_subnet_cidr = var.private_endpoint_subnet_cidr != null ? var.private_endpoint_subnet_cidr : local.calculated_subnet_cidr
}

# Create a dedicated subnet for private endpoints with new name
resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.environment}-integration-app-pe-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.aks_vnet.name
  address_prefixes     = [local.private_endpoint_subnet_cidr]

  # Ensure subnet is created before destroying old one
  lifecycle {
    create_before_destroy = true
  }
}

# Disable private endpoint network policies
resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "${var.environment}-integration-app-private-endpoints-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow inbound traffic from AKS cluster
  security_rule {
    name                       = "AllowAKSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["6379", "6380"] # Redis ports
    source_address_prefix      = data.azurerm_virtual_network.aks_vnet.address_space[0]
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}