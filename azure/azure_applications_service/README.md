# Azure Infrastructure for Integration.app

This Terraform module deploys the Integration.app application stack on Azure, providing an equivalent setup to the AWS deployment.

## Architecture Overview

### Core Components

1. **Azure Container Apps** - Managed container hosting for 4 services:
   - API Service (port 5000)
   - UI Service (port 5000)
   - Console Service (port 5000)
   - Custom Code Runner Service (port 5000, internal only)

2. **Azure Cache for Redis** - Caching layer (replaces AWS ElastiCache)

3. **Azure Storage Account** - Object storage with containers:
   - `integration-app-dev-temp` - Temporary files (7-day lifecycle)
   - `integration-app-connectors` - Connector files
   - `$web` - Static website hosting

4. **Azure Front Door** - CDN and load balancing for:
   - Static content (static.azure.int-membrane.com)
   - API endpoint (api.azure.int-membrane.com)
   - UI endpoint (ui.azure.int-membrane.com)
   - Console endpoint (console.azure.int-membrane.com)

5. **Azure Key Vault** - Secrets management for:
   - JWT signing secret
   - Encryption secret
   - Harbor registry credentials

6. **Virtual Network** - Network isolation with subnets:
   - Container subnet (10.0.1.0/24) - For Container Instances
   - Container Apps subnet (10.0.2.0/24) - For Container Apps
   - Data subnet (10.0.3.0/24) - For cache

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.11.3
- Azure CLI installed and authenticated
- Harbor registry access credentials
- Auth0 application credentials
- Service Principal with Owner permissions (see Service Principal Setup below)

## Service Principal Setup

The Terraform configuration requires a Service Principal with appropriate permissions. Here's how to set it up:

1. **Create a Service Principal** (if you don't have one):

   ```bash
   az ad sp create-for-rbac --name "integration-app-terraform" --role contributor \
     --scopes /subscriptions/YOUR_SUBSCRIPTION_ID
   ```

2. **Generate a new client secret** (if needed):

   ```bash
   az ad app credential reset --id YOUR_CLIENT_ID --years 2
   ```

3. **Grant Contributor role** to the Service Principal:

   ```bash
   az role assignment create --assignee YOUR_CLIENT_ID \
     --role "Contributor" \
     --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
   ```

4. **Grant Owner role** to the Service Principal (required for creating role assignments):
   ```bash
   az role assignment create --assignee YOUR_CLIENT_ID \
     --role "Owner" \
     --scope "/subscriptions/YOUR_SUBSCRIPTION_ID"
   ```

The Owner role is necessary because the Terraform configuration creates role assignments for Container Apps to access Storage Accounts.

## Configuration

1. Copy `terraform.tfvars-sample` to `terraform.tfvars`:

   ```bash
   cp terraform.tfvars-sample terraform.tfvars
   ```

2. Update the variables in `terraform.tfvars` with your values:
   ```hcl
   environment         = "dev"
   location           = "eastus"
   subscription_id    = "your-subscription-id"
   tenant_id          = "your-tenant-id"
   client_id          = "your-service-principal-client-id"
   client_secret      = "your-service-principal-client-secret"
   auth0_domain       = "your-domain.auth0.com"
   auth0_client_id    = "your-auth0-client-id"
   auth0_client_secret = "your-auth0-client-secret"
   harbor_username    = "your-harbor-username"
   harbor_password    = "your-harbor-password"
   ```

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

1. **DNS Configuration**: Update your DNS provider to point the azure.int-membrane.com subdomain to the Azure DNS zone nameservers shown in the output.

2. **Verify Services**: Once deployed, verify each service is accessible:
   - https://api.azure.int-membrane.com
   - https://ui.azure.int-membrane.com
   - https://console.azure.int-membrane.com
   - https://static.azure.int-membrane.com

3. **Monitor Health**: Check Azure Container Apps logs and metrics in the Azure Portal.

## Key Differences from AWS Deployment

| AWS Service         | Azure Equivalent        | Notes                                    |
| ------------------- | ----------------------- | ---------------------------------------- |
| ECS Fargate         | Azure Container Apps    | Fully managed serverless containers      |
| ElastiCache Redis   | Azure Cache for Redis   | Redis-compatible caching                 |
| S3                  | Azure Storage           | Blob storage with static website hosting |
| CloudFront          | Azure Front Door        | Global CDN and load balancer             |
| ALB                 | Azure Front Door        | Integrated with CDN                      |
| SSM Parameter Store | Azure Key Vault         | Centralized secrets management           |
| VPC                 | Virtual Network         | Network isolation                        |
| Security Groups     | Network Security Groups | Traffic filtering                        |

## Environment Variables

The Container Apps are configured with the following environment variables:

### API Service

- `NODE_ENV=production`
- `BASE_URI=https://api.azure.int-membrane.com`
- `AUTH0_DOMAIN`, `AUTH0_CLIENT_ID`, `AUTH0_CLIENT_SECRET`
- `MONGO_URI` (from Key Vault)
- `REDIS_URI` (Redis connection with SSL)
- `AZURE_STORAGE_CONNECTION_STRING`
- Storage container names for tmp, connectors, and static files

### UI Service

- `NEXT_PUBLIC_ENGINE_URI=https://api.azure.int-membrane.com`
- `PORT=5000`

### Console Service

- `NEXT_PUBLIC_BASE_URI=https://console.azure.int-membrane.com`
- `NEXT_PUBLIC_AUTH0_DOMAIN`
- `NEXT_PUBLIC_ENGINE_API_URI=https://api.azure.int-membrane.com`
- `NEXT_PUBLIC_ENGINE_UI_URI=https://ui.azure.int-membrane.com`
- `NEXT_PUBLIC_AUTH0_CLIENT_ID`

## Outputs

After deployment, Terraform will output:

- Storage account details
- AFD endpoint URLs
- Custom domain URLs
- Container App URLs
- DNS zone nameservers
- Redis hostname
- Key Vault URI

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Troubleshooting

1. **Container Apps not starting**: Check logs in Azure Portal > Container Apps > Logs
2. **Redis connection issues**: Check Redis firewall rules and SSL settings
3. **Storage access issues**: Verify storage account keys and connection strings
4. **DNS resolution**: Ensure DNS records are properly configured and propagated
