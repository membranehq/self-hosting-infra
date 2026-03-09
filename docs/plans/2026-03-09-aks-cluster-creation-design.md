# Design: AKS Cluster Creation in azure_kubernetes_service/

**Date:** 2026-03-09
**Status:** Approved

## Problem

The `azure/azure_kubernetes_service/` module currently assumes an AKS cluster already exists. It uses two data sources to look up the cluster and its VNet:

- `data "azurerm_kubernetes_cluster" "main"` — to get the OIDC issuer URL for External-DNS workload identity
- `data "azurerm_virtual_network" "aks_vnet"` — to discover the VNet for private endpoint subnet creation

Customers must provision the AKS cluster manually before running this module, creating a two-step process with no Terraform-managed cluster lifecycle.

## Goal

Extend `azure/azure_kubernetes_service/` so that a single `terraform apply` creates the full stack: VNet, AKS cluster, node pools, Redis, storage, Front Door, and External-DNS identity. The module becomes a complete self-contained deployment unit equivalent to `aws/eks/`.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Module structure | In-place extension of `azure_kubernetes_service/` | Single directory, single apply, consistent with EKS module shape |
| Network plugin | Azure CNI Overlay | Scales pod count without exhausting VNet IP space; production-recommended |
| Network policy | Cilium (eBPF data plane) | Better performance than Azure NPM; required with CNI Overlay |
| Node pool strategy | System pool + User pool | Isolates control-plane pods from app workloads |
| API server access | Public with `authorized_ip_ranges` | Simpler CI/CD integration; matches EKS module pattern |
| Observability | None (bring your own) | Prometheus/Grafana installed via Helm separately |
| Node identity | SystemAssigned managed identity | Simplest; no pre-created identity needed |
| OIDC / Workload Identity | Enabled | Required by existing External-DNS federated credential |

## Architecture

### File Changes

```
azure/azure_kubernetes_service/
  vnet.tf          ← NEW
  cluster.tf       ← NEW
  node_pools.tf    ← NEW
  network.tf       ← MODIFIED (data source → resource reference)
  external-dns-identity.tf ← MODIFIED (data source → resource reference)
  variables.tf     ← MODIFIED (add cluster vars, remove aks_vnet_name)
  outputs.tf       ← MODIFIED (add cluster_name, kube_config, endpoint)
```

### Dependency Graph

```
azurerm_virtual_network.main
  └── azurerm_subnet.nodes
        └── azurerm_kubernetes_cluster.main  ← system node pool embedded
              └── azurerm_kubernetes_cluster_node_pool.user
  └── azurerm_subnet.private_endpoints (network.tf, unchanged)
        ├── azurerm_private_endpoint.redis
        └── azurerm_private_endpoint.storage (future)
```

### Networking (vnet.tf)

Three non-overlapping CIDRs required by Azure CNI Overlay:

| Purpose | Default CIDR | Variable |
|---|---|---|
| VNet address space | `10.0.0.0/16` | `vnet_cidr` |
| Node subnet (within VNet) | `10.0.0.0/22` | `node_subnet_cidr` |
| Pod overlay (separate) | `192.168.0.0/16` | `pod_cidr` |
| Service ClusterIP range | `172.16.0.0/16` | `service_cidr` |

Private endpoints subnet continues to be allocated at offset 100 of the VNet (`10.0.100.0/24` by default), computed dynamically in `network.tf` from `azurerm_virtual_network.main.address_space[0]`.

### Cluster (cluster.tf)

```hcl
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  kubernetes_version  = var.kubernetes_version   # "1.31"

  default_node_pool {                            # system pool
    name                         = "system"
    vm_size                      = var.system_node_vm_size   # "Standard_D2s_v5"
    node_count                   = var.system_node_count     # 2
    only_critical_addons_enabled = true
    vnet_subnet_id               = azurerm_subnet.nodes.id
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 128
    upgrade_settings { max_surge = "10%" }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    ebpf_data_plane     = "cilium"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = cidrhost(var.service_cidr, 10)
  }

  identity { type = "SystemAssigned" }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  auto_upgrade_profile { upgrade_channel = "patch" }
}
```

### Node Pools (node_pools.tf)

```hcl
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.user_node_vm_size     # "Standard_D4s_v5"
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.nodes.id
  os_disk_type          = "Ephemeral"
  auto_scaling_enabled  = true
  min_count             = var.user_node_min_count    # 1
  max_count             = var.user_node_max_count    # 10
  upgrade_settings { max_surge = "33%" }
  lifecycle { ignore_changes = [node_count] }
}
```

### Data Source Promotions

`network.tf`: `data "azurerm_virtual_network" "aks_vnet"` removed. All references updated to `azurerm_virtual_network.main`.

`external-dns-identity.tf`: `data "azurerm_kubernetes_cluster" "main"` removed. `oidc_issuer_url` comes directly from `azurerm_kubernetes_cluster.main.oidc_issuer_url`.

## Variables

### Added

| Variable | Type | Default | Description |
|---|---|---|---|
| `kubernetes_version` | string | `"1.31"` | Kubernetes version |
| `vnet_cidr` | string | `"10.0.0.0/16"` | VNet address space |
| `node_subnet_cidr` | string | `"10.0.0.0/22"` | Node subnet CIDR |
| `pod_cidr` | string | `"192.168.0.0/16"` | Pod overlay CIDR (CNI Overlay) |
| `service_cidr` | string | `"172.16.0.0/16"` | Kubernetes service CIDR |
| `system_node_vm_size` | string | `"Standard_D2s_v5"` | VM size for system node pool |
| `system_node_count` | number | `2` | Fixed node count for system pool |
| `user_node_vm_size` | string | `"Standard_D4s_v5"` | VM size for user node pool |
| `user_node_min_count` | number | `1` | Min nodes in user pool |
| `user_node_max_count` | number | `10` | Max nodes in user pool |
| `api_server_authorized_ip_ranges` | list(string) | **required** | CIDRs allowed to reach API server |

### Removed

| Variable | Reason |
|---|---|
| `aks_vnet_name` | VNet is now created by the module |

### Unchanged

`aks_cluster_name`, `kubernetes_namespace`, `environment`, `location`, `project`, `resource_group_name`, `dns_zone_name`, `private_endpoint_subnet_cidr`, `cors_allowed_origins`, `external_dns_service_account_name`

## Outputs

### Added

| Output | Sensitive | Description |
|---|---|---|
| `cluster_name` | No | AKS cluster name |
| `cluster_endpoint` | No | Kubernetes API server FQDN |
| `kube_config` | **Yes** | Raw kubeconfig for `kubectl` |

## Migration for Existing Users

Customers who already deployed with a manually-created cluster can adopt this module by importing their existing resources before applying:

```bash
terraform import azurerm_virtual_network.main \
  /subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME

terraform import azurerm_subnet.nodes \
  /subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/SUBNET_NAME

terraform import azurerm_kubernetes_cluster.main \
  /subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.ContainerService/managedClusters/CLUSTER_NAME
```

After import, run `terraform plan` to verify no destructive changes before applying.
