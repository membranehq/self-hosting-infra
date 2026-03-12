locals {
  vnet_address_space           = tolist(azurerm_virtual_network.main.address_space)[0]
  calculated_subnet_cidr       = cidrsubnet(local.vnet_address_space, 8, 100)
  private_endpoint_subnet_cidr = var.private_endpoint_subnet_cidr != null ? var.private_endpoint_subnet_cidr : local.calculated_subnet_cidr
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.environment}-${var.project}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]

  tags = local.common_tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "${var.environment}-${var.project}-node-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.node_subnet_cidr]

  lifecycle {
    precondition {
      condition     = var.node_subnet_cidr != var.pod_cidr && var.node_subnet_cidr != var.service_cidr && var.pod_cidr != var.service_cidr
      error_message = "node_subnet_cidr, pod_cidr, and service_cidr must all be distinct. Check for CIDR overlap."
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "${var.environment}-integration-app-pe-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.private_endpoint_subnet_cidr]

  lifecycle {
    create_before_destroy = true
  }
}
