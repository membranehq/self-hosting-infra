# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${var.environment}-${var.project}-network-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]

  tags = local.common_tags
}

# Subnet for containers
resource "azurerm_subnet" "containers" {
  name                 = "${var.environment}-${var.project}-containers-snet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.4.0/24"]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Subnet for Azure Container Apps (alternative to ACI)
resource "azurerm_subnet" "container_apps" {
  name                 = "${var.environment}-${var.project}-containerapps-snet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/23"]

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault"
  ]
}

# Subnet for databases and cache
resource "azurerm_subnet" "data" {
  name                 = "${var.environment}-${var.project}-data-snet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]

  service_endpoints = [
    "Microsoft.Storage"
  ]
}

# Network Security Group for containers
resource "azurerm_network_security_group" "containers" {
  name                = "${var.environment}-${var.project}-containers-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-http"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-https"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with containers subnet
resource "azurerm_subnet_network_security_group_association" "containers" {
  subnet_id                 = azurerm_subnet.containers.id
  network_security_group_id = azurerm_network_security_group.containers.id
}

# NSG for data subnet
resource "azurerm_network_security_group" "data" {
  name                = "${var.environment}-${var.project}-data-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-redis-from-containers"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6379-6380"
    source_address_prefix      = azurerm_subnet.container_apps.address_prefixes[0]
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with data subnet
resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

resource "azurerm_private_endpoint" "membrane_redis_pe" {
  name                = "${var.environment}-${var.project}-redis-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.container_apps.id

  private_service_connection {
    name                           = "dev-membrane-redis-pe_844d736b-ae89-4a30-a5a3-0cba52b4301f"
    private_connection_resource_id = "/subscriptions/8efa5445-aa5c-402c-9975-80616017c233/resourceGroups/membrane-rg/providers/Microsoft.Cache/RedisEnterprise/dev-membrane"
    is_manual_connection           = false
    subresource_names = ["redisEnterprise"]
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      "/subscriptions/8efa5445-aa5c-402c-9975-80616017c233/resourceGroups/membrane-rg/providers/Microsoft.Network/privateDnsZones/privatelink.redis.azure.net",
    ]
  }
}
