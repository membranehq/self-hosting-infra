# Azure Kubernetes Service Infrastructure for Membrane

This Terraform module deploys the supporting Azure infrastructure for running Membrane on an **existing** AKS cluster. It does not provision the AKS cluster itself — it layers on the storage, caching, CDN, networking, and identity resources required by the application.

## Architecture Overview

### Core Components

1. **Azure Cache for Redis** - Caching and task queue layer (replaces AWS ElastiCache):
   - Standard C1 SKU with TLS 1.2 minimum
   - Private endpoint inside the AKS VNet
   - Private DNS zone linked to the AKS VNet for in-cluster resolution

2. **Azure Storage Account** - Object storage with containers:
   - `membrane-{env}-temp` - Temporary files (7-day lifecycle policy)
   - `membrane-{env}-connectors` - Connector files
   - `$web` - Static website hosting (auto-created by Azure)

3. **Azure Front Door** - CDN for static content (`static.{dns_zone_name}`):
   - Standard SKU with managed TLS certificate
   - Compression and 7-day cache rules for static assets
   - DNS validation record auto-created in the DNS zone

4. **External-DNS Managed Identity** - Workload identity for automatic DNS management:
   - User-assigned managed identity with DNS Zone Contributor role
   - Federated identity credential linked to the AKS OIDC issuer
   - Grants the `external-dns` Kubernetes service account permission to manage DNS records

5. **Network Infrastructure** - Private connectivity inside the AKS VNet:
   - Dedicated `/24` subnet for private endpoints
   - NSG allowing Redis ports (6379/6380) from the VNet CIDR

### What This Module Does NOT Create

- The AKS cluster itself (must exist before applying)
- The DNS zone (must exist before applying)
- The resource group (must exist before applying)
- Application secrets / Key Vault (manage these via Kubernetes secrets or External Secrets Operator)

## Prerequisites

- Existing AKS cluster with **OIDC issuer enabled** (required for workload identity)
- Existing Azure DNS zone in the same resource group
- Terraform >= 1.11.3
- Azure CLI installed and authenticated
- Service Principal with appropriate permissions (see Service Principal Setup below)

### Verify OIDC Issuer is Enabled

```bash
az aks show --name <your-cluster-name> --resource-group <your-resource-group> \
  --query "oidcIssuerProfile.enabled"
# Must return: true
```

To enable it if not already on:

```bash
az aks update --name <your-cluster-name> --resource-group <your-resource-group> \
  --enable-oidc-issuer
```

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

3. **Grant Owner role** on the resource group (required to create role assignments for External-DNS):

   ```bash
   az role assignment create --assignee YOUR_CLIENT_ID \
     --role "Owner" \
     --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/YOUR_RESOURCE_GROUP"
   ```

   The Owner role is necessary because this module creates `DNS Zone Contributor` and `Reader` role assignments for the External-DNS managed identity.

## Configuration

1. Copy `terraform.tfvars-sample` to `terraform.tfvars`:

   ```bash
   cp terraform.tfvars-sample terraform.tfvars
   ```

2. Update the variables in `terraform.tfvars` with your values:

   ```hcl
   environment          = "prod"
   location             = "eastus"
   project              = "membrane"
   resource_group_name  = "your-resource-group-name"
   dns_zone_name        = "your-dns-zone.example.com"

   aks_cluster_name     = "your-aks-cluster-name"
   kubernetes_namespace = "production"
   aks_vnet_name        = "your-aks-vnet-name"
   ```

   | Variable | Required | Default | Description |
   |---|---|---|---|
   | `environment` | No | `test` | Environment name (dev, staging, prod) |
   | `location` | No | `eastus` | Azure region |
   | `project` | No | `membrane` | Project name used in resource naming |
   | `resource_group_name` | No | `membrane-rg` | Resource group for all created resources |
   | `dns_zone_name` | No | `azure.int-membrane.com` | Azure DNS zone name |
   | `aks_cluster_name` | **Yes** | — | Name of the existing AKS cluster |
   | `kubernetes_namespace` | **Yes** | — | Kubernetes namespace where Integration.app is deployed |
   | `aks_vnet_name` | No | `aks-vnet-{cluster_name}` | AKS VNet name; auto-discovered if omitted |
   | `private_endpoint_subnet_cidr` | No | auto-calculated | CIDR for the private endpoints subnet |

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

1. **Configure External-DNS** in your AKS cluster using the identity outputs:

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

2. **Configure the Integration.app Helm chart** with storage and Redis values:

   ```bash
   terraform output redis_uri                  # sensitive - use as REDIS_URI env var
   terraform output storage_connection_string  # sensitive - use as AZURE_STORAGE_CONNECTION_STRING
   terraform output tmp_bucket_name
   terraform output connectors_bucket_name
   terraform output static_uri
   ```

3. **Upload static assets** to the `$web` container of the storage account for the Front Door origin to serve.

4. **Verify DNS validation**: After apply, Azure Front Door validates the custom domain via the TXT record created in the DNS zone. This can take up to 30 minutes.

## Key Differences from AWS Deployment

| AWS Service | Azure Equivalent | Notes |
|---|---|---|
| EKS | AKS | Cluster must exist before applying this module |
| ElastiCache Redis | Azure Cache for Redis | Redis-compatible, connected via private endpoint |
| S3 | Azure Storage Account | Blob storage with static website hosting |
| CloudFront | Azure Front Door | Standard SKU, static content only |
| Route53 + ExternalDNS IAM | Azure DNS + External-DNS Workload Identity | Federated credential via OIDC issuer |
| IRSA | Azure Workload Identity | Pod-level identity via federated credentials |

## Outputs

After deployment, Terraform will output:

| Output | Sensitive | Description |
|---|---|---|
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

> **Note**: This will not delete the AKS cluster, DNS zone, or resource group, as those are not managed by this module.

## Troubleshooting

1. **Private endpoint subnet CIDR conflict**: If `terraform apply` fails with a subnet address conflict, set `private_endpoint_subnet_cidr` explicitly to an unused `/24` block within the VNet address space.

2. **Redis connection refused from pods**: Confirm the private DNS zone `privatelink.redis.cache.windows.net` is linked to the AKS VNet. Check with:
   ```bash
   az network private-dns link vnet list \
     --resource-group <resource-group> \
     --zone-name privatelink.redis.cache.windows.net
   ```

3. **External-DNS not creating records**: Verify the federated credential subject matches the actual service account:
   ```bash
   kubectl get serviceaccount external-dns -n <namespace> \
     -o jsonpath='{.metadata.annotations}'
   # Should include: azure.workload.identity/client-id
   ```

4. **Front Door custom domain stuck in pending validation**: Check the TXT record was created:
   ```bash
   az network dns record-set txt show \
     --resource-group <resource-group> \
     --zone-name <dns_zone_name> \
     --name _dnsauth.static
   ```

5. **Static website not served via Front Door**: Ensure static files are uploaded to the `$web` container, not the `connectors` or `tmp` containers.
