resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_vm_size
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.nodes.id
  os_disk_type          = "Ephemeral" # must be explicit; default is Managed
  os_disk_size_gb       = 128         # 128 GiB of 150 GiB available on Standard_D4s_v5 cache disk

  auto_scaling_enabled = true
  min_count            = var.user_node_min_count
  max_count            = var.user_node_max_count

  upgrade_settings {
    # Absolute count ensures 1 surge node even at minimum scale (min_count=1).
    # 33% of 1 node rounds to 0, which would stall upgrades.
    max_surge = "1"
  }

  tags = local.common_tags

  lifecycle {
    # Autoscaler modifies node_count outside Terraform. Ignore drift to prevent spurious plan changes.
    ignore_changes = [node_count]
  }
}
