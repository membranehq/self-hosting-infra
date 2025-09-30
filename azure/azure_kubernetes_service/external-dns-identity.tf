# Data source to get current client configuration
data "azurerm_client_config" "current" {}

# User-assigned managed identity for External-DNS
resource "azurerm_user_assigned_identity" "external_dns" {
  name                = "${var.project}-${var.environment}-external-dns"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = local.common_tags
}

# Get the DNS zone data
data "azurerm_dns_zone" "main" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
}

# Role assignment for External-DNS to manage DNS records
resource "azurerm_role_assignment" "external_dns_zone_contributor" {
  scope                = data.azurerm_dns_zone.main.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

# Role assignment for External-DNS to read resource groups (needed to discover DNS zones)
resource "azurerm_role_assignment" "external_dns_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
}

# Data source to get AKS cluster OIDC issuer URL
data "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  resource_group_name = var.resource_group_name
}

# Federated identity credential for Workload Identity
resource "azurerm_federated_identity_credential" "external_dns" {
  name                = "external-dns-federation"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.main.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  subject             = "system:serviceaccount:${var.kubernetes_namespace}:external-dns"
}