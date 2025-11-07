# Integration.app GCP Cloud Run Deployment

This Terraform configuration deploys Integration.app on Google Cloud Platform using Cloud Run services. This is the GCP equivalent of the Azure Application Service deployment.

## Architecture Overview

This deployment creates a complete Integration.app environment on GCP with the following components:

### Services Deployed

| Azure Service | GCP Equivalent | Description |
|---------------|----------------|-------------|
| Azure Container Apps | Cloud Run | Serverless container platform |
| Azure Cache for Redis | Memorystore for Redis | Managed Redis instance |
| Azure Storage Account | Cloud Storage | Object storage buckets |
| Azure Front Door | Cloud Load Balancing + Cloud CDN | Global load balancing and CDN |
| Azure DNS | Cloud DNS | DNS hosting |
| Azure Key Vault | Secret Manager | Secrets management |
| Azure VNet | VPC Network | Virtual private network |
| Azure Container Registry | Artifact Registry | Container image registry (remote repository mode) |

### Cloud Run Services

1. **API Service** - Main application API (public, autoscaling)
2. **UI Service** - User interface (public, autoscaling)
3. **Console Service** - Admin console (public, autoscaling)
4. **Custom Code Runner** - Executes user code (internal only)
5. **Instant Tasks Worker** - High-priority task processing (internal only)
6. **Queued Tasks Worker** - Background task processing (internal only)
7. **Orchestrator** - Task scheduling and orchestration (internal only)

### Storage Buckets

- **tmp** - Temporary files (7-day lifecycle)
- **connectors** - Connector definitions
- **static** - Static website content (CDN-enabled)

### Container Registry

GCP Cloud Run requires container images to be hosted in authorized registries. This deployment uses **Artifact Registry Remote Repository** to proxy Harbor registry images:

- **Remote Repository Mode**: Artifact Registry acts as a pull-through cache for Harbor
- **Automatic Authentication**: Harbor credentials are stored in Secret Manager and used by Artifact Registry
- **Transparent Proxying**: Cloud Run services pull from Artifact Registry, which fetches from Harbor
- **Image Path Format**: `{region}-docker.pkg.dev/{project-id}/{repo-id}/harbor.integration.app/core/{service}:{tag}`

This approach complies with GCP's security requirements while maintaining compatibility with Harbor as the source registry.

## Prerequisites

1. **GCP Account** with billing enabled
2. **GCP Project** created
3. **Required APIs enabled**:
   ```bash
   gcloud services enable run.googleapis.com
   gcloud services enable compute.googleapis.com
   gcloud services enable redis.googleapis.com
   gcloud services enable storage.googleapis.com
   gcloud services enable dns.googleapis.com
   gcloud services enable secretmanager.googleapis.com
   gcloud services enable servicenetworking.googleapis.com
   gcloud services enable vpcaccess.googleapis.com
   gcloud services enable artifactregistry.googleapis.com
   ```

4. **Terraform** >= 1.11.3 installed
5. **gcloud CLI** installed and authenticated
6. **Domain name** for custom domains
7. **MongoDB** database (MongoDB Atlas recommended)
8. **Auth0** tenant configured
9. **Harbor registry** credentials

## Getting Started

### 1. Authenticate with GCP

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Configure Variables

Copy the sample configuration:

```bash
cp terraform.tfvars.sample terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
project_id  = "your-gcp-project-id"
region      = "europe-west3"
environment = "dev"

domain_name = "your-domain.com"

auth0_domain        = "your-tenant.auth0.com"
auth0_client_id     = "your-client-id"
auth0_client_secret = "your-client-secret"

mongo_uri = "mongodb+srv://..."

harbor_username = "robot$customer-name"
harbor_password = "your-password"
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

### 5. Deploy

```bash
terraform apply
```

The deployment takes approximately 20-30 minutes.

## Post-Deployment Steps

### 1. Update DNS Nameservers

After deployment, update your domain's nameservers to point to the Cloud DNS nameservers shown in the output:

```bash
terraform output dns_zone_name_servers
```

Go to your domain registrar and update the nameservers.

### 2. Wait for SSL Certificates

Managed SSL certificates are automatically provisioned after DNS is configured. This takes 15-60 minutes.

Monitor certificate status:

```bash
gcloud compute ssl-certificates describe dev-membrane-api-cert --global
```

Look for `status: ACTIVE` in the output.

### 3. Access Your Services

Once DNS propagates and SSL certificates are active:

```bash
terraform output custom_domain_urls
```

- API: `https://api.dev.your-domain.com`
- UI: `https://ui.dev.your-domain.com`
- Console: `https://console.dev.your-domain.com`
- Static: `https://static.dev.your-domain.com`

## Configuration

### Environment-Based Domains

Domains are automatically configured based on the `environment` variable:

- **prod**: `api.domain.com`
- **dev/stage**: `api.dev.domain.com`, `api.stage.domain.com`

### Resource Sizing

Adjust Cloud Run service resources in `terraform.tfvars`:

```hcl
# API Service
api_cpu          = "1"      # vCPUs (1, 2, 4, 8)
api_memory       = "2Gi"    # Memory (512Mi, 1Gi, 2Gi, 4Gi, 8Gi)
api_min_instances = 1       # Minimum instances (0-1000)
api_max_instances = 10      # Maximum instances (1-1000)
```

### Redis Configuration

```hcl
redis_tier          = "BASIC"        # BASIC or STANDARD_HA
redis_memory_size_gb = 1             # 1-300 GB
redis_version       = "REDIS_7_0"    # REDIS_6_X or REDIS_7_0
```

### Cost Optimization

For development environments:
- Use `redis_tier = "BASIC"` (no HA)
- Set `min_instances = 0` for non-critical services (allows scale to zero)
- Use smaller memory/CPU allocations

For production:
- Use `redis_tier = "STANDARD_HA"` (high availability)
- Keep `min_instances >= 1` for critical services
- Enable request-based autoscaling

## Networking

### VPC Configuration

- **VPC Network**: Custom VPC with private IP ranges
- **Subnet**: `10.0.0.0/24` for Cloud Run services
- **VPC Connector**: Allows Cloud Run to access VPC resources
- **Cloud NAT**: Provides outbound internet access
- **Private Service Access**: For Memorystore Redis

### Firewall Rules

- Internal communication: All ports within `10.0.0.0/8`
- Health checks: Port 5000 from GCP load balancer ranges

### Service Connectivity

- **Public Services**: API, UI, Console (accessible via Load Balancer)
- **Internal Services**: Custom Code Runner, Workers, Orchestrator (VPC only)
- **Redis**: Accessible only from VPC via private IP

## Security

### Secret Management

All secrets are stored in Secret Manager:
- JWT secrets (auto-generated)
- Encryption secrets (auto-generated)
- MongoDB URI
- Auth0 client secret
- Harbor credentials

### IAM Permissions

Cloud Run services automatically get:
- Read access to their required secrets
- Read/write access to storage buckets
- Network access to Redis

### Storage Access

- **tmp, connectors**: Private (service accounts only)
- **static**: Public read (for CDN)

## Monitoring

### Cloud Run Metrics

View in Cloud Console:
```
https://console.cloud.google.com/run
```

Key metrics:
- Request count
- Request latency
- Container instance count
- Memory/CPU utilization

### Logs

View logs:
```bash
gcloud run services logs read api --region=europe-west3
gcloud run services logs read queued-tasks-worker --region=europe-west3
```

### Redis Monitoring

```bash
gcloud redis instances describe dev-membrane-redis --region=europe-west3
```

## Troubleshooting

### SSL Certificate Not Provisioning

1. Verify DNS is configured correctly:
   ```bash
   dig api.dev.your-domain.com
   ```

2. Check certificate status:
   ```bash
   gcloud compute ssl-certificates describe dev-membrane-api-cert --global
   ```

3. SSL provisioning can take up to 60 minutes after DNS is configured

### Service Not Responding

1. Check Cloud Run service status:
   ```bash
   gcloud run services describe api --region=europe-west3
   ```

2. View recent logs:
   ```bash
   gcloud run services logs read api --region=europe-west3 --limit=50
   ```

3. Verify IAM permissions for service account

### Redis Connection Issues

1. Verify VPC connector is working:
   ```bash
   gcloud compute networks vpc-access connectors describe dev-membrane-connector --region=europe-west3
   ```

2. Check Redis instance status:
   ```bash
   gcloud redis instances describe dev-membrane-redis --region=europe-west3
   ```

### Storage Access Issues

1. Verify bucket exists:
   ```bash
   gsutil ls gs://your-project-id-dev-membrane-tmp
   ```

2. Check IAM permissions:
   ```bash
   gsutil iam get gs://your-project-id-dev-membrane-tmp
   ```

## Maintenance

### Updating Container Images

Update the `image_tag` variable and re-deploy:

```hcl
image_tag = "v1.2.3"
```

```bash
terraform apply
```

Cloud Run will perform a rolling update with zero downtime.

### Scaling Configuration

Adjust min/max instances and re-apply:

```hcl
api_min_instances = 2
api_max_instances = 20
```

```bash
terraform apply
```

### Backup and Disaster Recovery

**Storage Buckets**:
- Enable versioning:
  ```bash
  gsutil versioning set on gs://your-bucket-name
  ```

**Redis**:
- Standard HA tier includes automatic failover
- Export data manually:
  ```bash
  gcloud redis instances export gs://backup-bucket/redis-backup.rdb dev-membrane-redis --region=europe-west3
  ```

## Cost Estimation

Approximate monthly costs (dev environment):

| Resource | Configuration | Estimated Cost |
|----------|--------------|----------------|
| Cloud Run (7 services) | 1 CPU, 2GB RAM, minimal traffic | $50-100 |
| Memorystore Redis | BASIC, 1GB | $50 |
| Cloud Storage | 10GB, minimal egress | $1-5 |
| Load Balancing | 5 forwarding rules, minimal traffic | $20-30 |
| Cloud DNS | 1 zone | $0.20 |
| Secret Manager | 5 secrets | $0.18 |
| **Total** | | **~$120-185/month** |

Production costs will be higher based on:
- Traffic volume
- Instance counts
- Redis HA tier
- Data storage and egress

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources, including storage buckets and data.

## Comparison with Azure Deployment

| Feature | Azure | GCP |
|---------|-------|-----|
| Container Platform | Container Apps | Cloud Run |
| Autoscaling | Built-in KEDA | Built-in request-based |
| Redis | Azure Cache / Managed Redis | Memorystore |
| Storage | Storage Account | Cloud Storage |
| CDN | Azure Front Door | Cloud CDN + Load Balancing |
| Secrets | Key Vault | Secret Manager |
| DNS | Azure DNS | Cloud DNS |
| Private Networking | VNet | VPC |

## Support

For issues related to:
- **Infrastructure**: Check this README and Terraform documentation
- **Application**: Contact Integration.app support
- **GCP Platform**: See [GCP Documentation](https://cloud.google.com/docs)

## Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Memorystore for Redis](https://cloud.google.com/memorystore/docs/redis)
- [Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)
- [Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
