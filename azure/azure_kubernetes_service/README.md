# Azure Kubernetes Service Infrastructure for Membrane

This Terraform module creates a complete Azure infrastructure stack for running Membrane on AKS:
VNet, AKS cluster, node pools, Redis, Blob Storage, Azure Front Door, and External-DNS workload identity.
A single `terraform apply` provisions everything from scratch.

## Architecture Overview

### Core Components

1. **Virtual Network** - Isolated network for all cluster and application resources:
   - Node subnet for AKS nodes (Azure CNI Overlay)
   - Private endpoint subnet for Azure services
   - NSG on the private endpoint subnet (Redis ports 6379/6380 from VNet)

2. **AKS Cluster** - Kubernetes 1.32 with Azure CNI Overlay and Cilium eBPF dataplane:
   - System node pool: 2× Standard_D2s_v5, fixed count, Ephemeral OS, critical addons only
   - User node pool: Standard_D4s_v5, auto-scales 1–10 nodes, Ephemeral OS
   - OIDC issuer + Workload Identity enabled
   - Patch auto-upgrade channel
   - Network Contributor role on node subnet

3. **Azure Cache for Redis** - Caching and task queue layer:
   - Standard C1 SKU with TLS 1.2 minimum
   - Private endpoint inside the node VNet
   - Private DNS zone linked to the VNet for in-cluster resolution

4. **Azure Storage Account** - Object storage with containers:
   - `membrane-{env}-temp` - Temporary files (7-day lifecycle policy)
   - `membrane-{env}-connectors` - Connector files
   - `$web` - Static website hosting (auto-created by Azure)

5. **Azure Front Door** - CDN for static content (`static.{dns_zone_name}`):
   - Standard SKU with managed TLS certificate
   - Compression and 7-day cache rules for static assets
   - DNS validation record auto-created in the DNS zone

6. **External-DNS Managed Identity** - Workload identity for automatic DNS management:
   - User-assigned managed identity with DNS Zone Contributor role
   - Federated identity credential linked to the AKS OIDC issuer
   - Grants the `external-dns` Kubernetes service account permission to manage DNS records

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.5.0
- Azure CLI installed and authenticated
- Existing Azure DNS zone in the resource group
- Service Principal with Owner permissions on the resource group (see Service Principal Setup)

### One-time subscription setup

Azure CNI Overlay and Cilium dataplane are GA for AKS 1.28+. Ensure the resource provider is registered:

```bash
az provider show --namespace Microsoft.ContainerService --query registrationState
# Expected: "Registered"

# If not registered:
az provider register --namespace Microsoft.ContainerService
```

No feature flag registration is required for AKS 1.32 with Azure CNI Overlay and Cilium.

## Service Principal Setup

The Terraform configuration requires a Service Principal with permissions to create resources and assign roles.

1. **Create a Service Principal** (if you don't have one):

   ```bash
   az ad sp create-for-rbac --name "membrane-terraform" --role contributor \
     --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
   ```

2. **Grant Contributor role** on the resource group:

   ```bash
   az role assignment create --assignee YOUR_CLIENT_ID \
     --role "Contributor" \
     --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP"
   ```

3. **Grant Owner role** on the resource group (required to create role assignments for External-DNS and AKS):

   ```bash
   az role assignment create --assignee YOUR_CLIENT_ID \
     --role "Owner" \
     --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP"
   ```

   The Owner role is necessary because this module creates `DNS Zone Contributor`, `Reader`, and `Network Contributor` role assignments.

## Configuration

1. Copy `terraform.tfvars-sample` to `terraform.tfvars`:

   ```bash
   cp terraform.tfvars-sample terraform.tfvars
   ```

2. Update the variables in `terraform.tfvars` with your values.

   | Variable | Required | Default | Description |
   |---|---|---|---|
   | `environment` | No | `test` | Environment name (dev, staging, prod) |
   | `location` | No | `eastus` | Azure region |
   | `project` | No | `integration-app` | Project name used in resource naming |
   | `resource_group_name` | No | `integration-app-rg` | Resource group for all created resources |
   | `dns_zone_name` | No | `azure.int-membrane.com` | Azure DNS zone name |
   | `aks_cluster_name` | **Yes** | — | Name of the AKS cluster to create |
   | `kubernetes_namespace` | **Yes** | — | Kubernetes namespace where Integration.app is deployed |
   | `kubernetes_version` | No | `1.32` | Kubernetes version |
   | `vnet_cidr` | No | `10.0.0.0/16` | VNet address space |
   | `node_subnet_cidr` | No | `10.0.0.0/22` | Node subnet CIDR (must not overlap pod/service CIDRs) |
   | `pod_cidr` | No | `192.168.0.0/16` | Pod overlay CIDR — override if conflicts with peered/on-prem ranges |
   | `service_cidr` | No | `172.16.0.0/16` | Kubernetes service CIDR |
   | `system_node_vm_size` | No | `Standard_D2s_v5` | System pool VM size (os_disk_size_gb capped at cache size) |
   | `system_node_count` | No | `2` | System pool fixed count |
   | `user_node_vm_size` | No | `Standard_D4s_v5` | User pool VM size |
   | `user_node_min_count` | No | `1` | User pool min nodes |
   | `user_node_max_count` | No | `10` | User pool max nodes |
   | `api_server_authorized_ip_ranges` | **Yes** | — | CIDRs for API server access (non-empty, no 0.0.0.0/0) |
   | `private_endpoint_subnet_cidr` | No | auto-calculated | CIDR for the private endpoints subnet |
   | `cors_allowed_origins` | **Yes** | — | Allowed origins for storage CORS |

## Deployment

1. Initialize Terraform:

   ```bash
   terraform init
   ```

2. Review the planned changes:

   ```bash
   terraform plan
   ```

3. Apply the configuration:

   ```bash
   terraform apply
   ```

## Post-Deployment Steps

1. **Configure kubectl** to access the cluster:

   ```bash
   az aks get-credentials --resource-group <resource-group> --name <cluster-name>
   # Or use the kubeconfig output (stored encrypted in state):
   terraform output -raw kube_config > ~/.kube/aks-config
   ```

2. **Configure External-DNS** in your AKS cluster using the identity outputs:

   ```bash
   terraform output external_dns_identity_client_id
   terraform output external_dns_identity_resource_id
   terraform output tenant_id
   terraform output dns_zone_name
   terraform output resource_group_name
   ```

   Pass these values to your External-DNS Helm chart values:

   ```yaml
   provider: azure
   azure:
     tenantId: "<tenant_id output>"
     subscriptionId: "<your-subscription-id>"
     resourceGroup: "<resource_group_name output>"
   serviceAccount:
     annotations:
       azure.workload.identity/client-id: "<external_dns_identity_client_id output>"
   podLabels:
     azure.workload.identity/use: "true"
   domainFilters:
     - "<dns_zone_name output>"
   ```

3. **Configure the Integration.app Helm chart** with storage and Redis values:

   ```bash
   terraform output redis_uri                  # sensitive - use as REDIS_URI env var
   terraform output storage_connection_string  # sensitive - use as AZURE_STORAGE_CONNECTION_STRING
   terraform output tmp_bucket_name
   terraform output connectors_bucket_name
   terraform output static_uri
   ```

4. **Upload static assets** to the `$web` container of the storage account for the Front Door origin to serve.

5. **Verify DNS validation**: After apply, Azure Front Door validates the custom domain via the TXT record created in the DNS zone. This can take up to 30 minutes.

## Migration for Existing Users

If you have an existing AKS cluster and VNet that were created outside Terraform, you can import them into state rather than recreating.

### Phase 0 — Verify CNI plugin compatibility

This module manages an AKS cluster using Azure CNI Overlay. Clusters created with kubenet or standard Azure CNI (non-overlay) **cannot be migrated** — they must be recreated.

```bash
az aks show \
  --resource-group <RG> \
  --name <CLUSTER_NAME> \
  --query "networkProfile.{plugin:networkPlugin,mode:networkPluginMode}" \
  --output json
```

Expected output (both fields must match):

```json
{"mode": "Overlay", "plugin": "azure"}
```

If the output is different, do not proceed with import. Plan a blue-green migration: provision a new cluster with this module, migrate workloads using kubectl, then decommission the old cluster.

### Phase 1 — Import existing resources

**Preferred approach (Terraform ≥ 1.5.0):** Create a temporary `imports.tf` file with native import blocks. This makes the migration plan-visible and reviewable before applying:

```hcl
# Create this file as azure/azure_kubernetes_service/imports.tf before running terraform plan
import {
  to = azurerm_virtual_network.main
  id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME"
}
import {
  to = azurerm_subnet.nodes
  id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/NODE_SUBNET_NAME"
}
import {
  to = azurerm_subnet.private_endpoints
  id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/PE_SUBNET_NAME"
}
import {
  to = azurerm_network_security_group.private_endpoints
  id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/networkSecurityGroups/NSG_NAME"
}
import {
  to = azurerm_subnet_network_security_group_association.private_endpoints
  id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/PE_SUBNET_NAME"
}
import {
  to = azurerm_kubernetes_cluster.main
  id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.ContainerService/managedClusters/CLUSTER_NAME"
}
# Only if a Network Contributor role assignment already exists for the cluster identity:
# import {
#   to = azurerm_role_assignment.aks_network_contributor
#   id = "/subscriptions/SUB_ID/resourceGroups/RG/providers/Microsoft.Network/virtualNetworks/VNET_NAME/subnets/NODE_SUBNET_NAME/providers/Microsoft.Authorization/roleAssignments/ASSIGNMENT_ID"
# }
```

If no Network Contributor role assignment exists yet, omit the last import block — Terraform will create it.

### Phase 2 — Verify no destructive changes

```bash
terraform plan -out=import.tfplan
```

Review the plan output carefully. Acceptable: `~` (in-place update) for tag diffs.
**Stop if you see `-/+` (destroy+recreate) or `-` (destroy) for any imported resource.**

Remove `imports.tf` after the plan is verified clean — import blocks are one-time operations.

### Phase 3 — Apply only after clean plan

```bash
terraform apply import.tfplan
rm azure/azure_kubernetes_service/imports.tf
```

## Key Differences from AWS Deployment

| AWS Service | Azure Equivalent | Notes |
|---|---|---|
| EKS | AKS | Provisioned by this module (Azure CNI Overlay + Cilium) |
| ElastiCache Redis | Azure Cache for Redis | Redis-compatible, connected via private endpoint |
| S3 | Azure Storage Account | Blob storage with static website hosting |
| CloudFront | Azure Front Door | Standard SKU, static content only |
| Route53 + ExternalDNS IAM | Azure DNS + External-DNS Workload Identity | Federated credential via OIDC issuer |
| IRSA | Azure Workload Identity | Pod-level identity via federated credentials |

## Outputs

| Output | Sensitive | Description |
|---|---|---|
| `cluster_name` | No | AKS cluster name |
| `cluster_api_server_url` | No | Kubernetes API server URL |
| `kube_config` | **Yes** | Raw kubeconfig — requires encrypted state backend |
| `tmp_bucket_name` | No | Name of the temporary files container |
| `connectors_bucket_name` | No | Name of the connectors container |
| `redis_uri` | **Yes** | Redis connection string (SSL) |
| `storage_connection_string` | **Yes** | Storage account connection string |
| `static_uri` | No | HTTPS URL for the Front Door static endpoint |
| `external_dns_identity_client_id` | No | Client ID for External-DNS workload identity |
| `external_dns_identity_resource_id` | No | Resource ID for External-DNS managed identity |
| `dns_zone_name` | No | DNS zone name for External-DNS `domainFilters` |
| `resource_group_name` | No | Resource group name for External-DNS config |
| `tenant_id` | No | Azure tenant ID for External-DNS config |

## Cleanup

To destroy all resources created by this module:

```bash
terraform destroy
```

> **Note**: This will delete the AKS cluster, VNet, Redis, storage, and Front Door. It will not delete the DNS zone or resource group, as those are not managed by this module.

## Troubleshooting

1. **CIDR overlap error on plan**: Ensure `node_subnet_cidr`, `pod_cidr`, and `service_cidr` are all distinct and non-overlapping with each other and with `vnet_cidr`.

2. **Node provisioning fails after apply**: Verify the `azurerm_role_assignment.aks_network_contributor` was created. With `SystemAssigned` identity there can be a timing issue — run `terraform apply` a second time if needed.

3. **Private endpoint subnet CIDR conflict**: If `terraform apply` fails with a subnet address conflict, set `private_endpoint_subnet_cidr` explicitly to an unused `/24` block within the VNet address space.

4. **Redis connection refused from pods**: Confirm the private DNS zone `privatelink.redis.cache.windows.net` is linked to the AKS VNet. Check with:
   ```bash
   az network private-dns link vnet list \
     --resource-group <resource-group> \
     --zone-name privatelink.redis.cache.windows.net
   ```

5. **External-DNS not creating records**: Verify the federated credential subject matches the actual service account:
   ```bash
   kubectl get serviceaccount external-dns -n <namespace> \
     -o jsonpath='{.metadata.annotations}'
   # Should include: azure.workload.identity/client-id
   ```

6. **Front Door custom domain stuck in pending validation**: Check the TXT record was created:
   ```bash
   az network dns record-set txt show \
     --resource-group <resource-group> \
     --zone-name <dns_zone_name> \
     --name _dnsauth.static
   ```

7. **Static website not served via Front Door**: Ensure static files are uploaded to the `$web` container, not the `connectors` or `tmp` containers.
