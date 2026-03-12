resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.aks_cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    node_count                   = var.system_node_count
    only_critical_addons_enabled = true
    vnet_subnet_id               = azurerm_subnet.nodes.id
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 75 # Standard_D2s_v5 cache = 75 GiB; must not exceed cache size

    upgrade_settings {
      # Absolute count ensures 1 surge node even at minimum scale.
      # 10% of 2 nodes rounds to 0, stalling upgrades.
      max_surge = "1"
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium" # renamed from ebpf_data_plane in azurerm 4.0
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  automatic_upgrade_channel = "patch"

  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }

  tags = local.common_tags
}

# AKS requires Network Contributor on the node subnet to manage route tables and NIC attachments.
# Without this, terraform apply succeeds but node provisioning fails silently.
#
# NOTE: With SystemAssigned identity, the role assignment depends on the cluster's principal_id
# which is only known after cluster creation. Terraform resolves this in a single apply but
# if the first apply fails due to a timing issue, run terraform apply again. Alternatively,
# use a UserAssigned identity to guarantee the assignment exists before cluster creation.
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.nodes.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
