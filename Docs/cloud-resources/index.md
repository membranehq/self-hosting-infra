# Cloud Resources

This guide covers the cloud infrastructure required to run Membrane. You'll need to provision storage, databases, and caching services before deploying Membrane services.

## Required Resources

### Cloud Storage

Membrane requires three storage buckets/containers for different purposes:

1. **Temporary Storage** (`TMP_STORAGE_BUCKET`)
   - Stores temporary files, logs, and processing artifacts
   - Recommended: Auto-expiration policy (7 days)
   - High churn rate - frequent writes and deletes

2. **Connectors Storage** (`CONNECTORS_STORAGE_BUCKET`)
   - Stores custom connector packages (.zip files)
   - Long-term storage
   - Versioning recommended

3. **Static Storage** (`STATIC_STORAGE_BUCKET`)
   - Stores user-uploaded static files (images, documents)
   - Must be publicly accessible via CDN/CORS
   - Served to end users through `BASE_STATIC_URI`

### MongoDB Database

Membrane requires MongoDB for persistent data storage.

#### Recommended: MongoDB Atlas

We strongly recommend using **MongoDB Atlas** (managed MongoDB) for reliability and ease of management.

**Minimum version:** MongoDB 4.4 or higher

**Configuration recommendations:**
- Replica set (minimum 3 nodes for production)
- Automated backups enabled
- Connection string format: `mongodb+srv://`

#### MongoDB Atlas Setup (Terraform Example)

```hcl
# Configure MongoDB Atlas provider
terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.14"
    }
  }
}

provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
}

# Create a project
resource "mongodbatlas_project" "membrane" {
  name   = "membrane-${var.environment}"
  org_id = var.mongodb_atlas_org_id
}

# Create a cluster
resource "mongodbatlas_cluster" "membrane" {
  project_id = mongodbatlas_project.membrane.id
  name       = "membrane-${var.environment}"

  # Provider settings
  provider_name               = "AWS"  # or "AZURE", "GCP"
  provider_region_name        = "US_EAST_1"
  provider_instance_size_name = "M10"  # Minimum recommended for production

  # Cluster configuration
  cluster_type = "REPLICASET"

  # MongoDB version
  mongo_db_major_version = "7.0"

  # Backup configuration
  backup_enabled               = true
  pit_enabled                  = true  # Point-in-time recovery
  cloud_backup                 = true
  auto_scaling_disk_gb_enabled = true
}

# Create database user
resource "mongodbatlas_database_user" "membrane" {
  username           = "membrane-app"
  password           = var.mongodb_password  # Use a secrets manager
  project_id         = mongodbatlas_project.membrane.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = "membrane-${var.environment}"
  }
}

# Configure IP access list (whitelist your infrastructure)
resource "mongodbatlas_project_ip_access_list" "membrane" {
  project_id = mongodbatlas_project.membrane.id
  cidr_block = var.allowed_cidr_block  # Your VPC CIDR or specific IPs
  comment    = "Membrane infrastructure access"
}

# Output connection string
output "mongodb_connection_string" {
  value     = mongodbatlas_cluster.membrane.connection_strings[0].standard_srv
  sensitive = true
}
```

**Connection String Format:**

```
mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<database>?retryWrites=true&w=majority
```

#### Alternative: Self-Hosted MongoDB

If you prefer to self-host MongoDB:

- Deploy on VMs with replica set configuration
- Ensure proper backup strategy
- Monitor disk space and performance
- Version 4.4+ required

**Not Supported:**
- ❌ AWS DocumentDB - Known compatibility issues with MongoDB API implementation
- ❌ Azure Cosmos DB (MongoDB API) - Not fully compatible

### Redis

Membrane uses Redis for caching and job queues.

**Minimum version:** Redis 6.0 or higher

**Important:** Redis is used only as a cache and job queue. Data in Redis is ephemeral and can be safely cleared or restarted without data loss.

#### Configuration Options

**Single Instance:**
```
REDIS_URI=redis://username:password@redis-host:6379
```

**Redis Cluster:**
```
REDIS_CLUSTER_URI_1=redis://username:password@node1:6379
REDIS_CLUSTER_URI_2=redis://username:password@node2:6379
REDIS_CLUSTER_URI_3=redis://username:password@node3:6379
```

**Not Supported:**
- ❌ AWS ElastiCache Serverless for Redis - Not compatible with our Redis usage patterns

#### Recommended Managed Services

- **AWS:** Amazon ElastiCache for Redis (Cluster Mode or Standard)
- **Azure:** Azure Cache for Redis (Standard or Premium tier)
- **GCP:** Google Cloud Memorystore for Redis

See cloud-specific guides for detailed setup:
- [AWS Redis Setup](aws.md#redis)
- [Azure Redis Setup](azure.md#redis)
- [GCP Redis Setup](gcp.md#redis)

## Cloud-Specific Guides

Each cloud provider has specific services and configuration patterns for storage, networking, and access control:

- [**AWS Resources**](aws.md) - S3, ElastiCache, CloudFront, IAM
- [**Azure Resources**](azure.md) - Blob Storage, Azure Cache for Redis, Front Door
- [**Google Cloud Resources**](gcp.md) - Cloud Storage, Memorystore, Cloud CDN

## Infrastructure Summary

| Resource Type | Purpose | Managed Service (Recommended) |
|---------------|---------|-------------------------------|
| Database | Primary data storage | MongoDB Atlas |
| Cache/Queue | Redis caching and job processing | ElastiCache / Azure Cache / Memorystore |
| Storage (Temp) | Temporary files, logs | S3 / Blob Storage / Cloud Storage |
| Storage (Connectors) | Connector packages | S3 / Blob Storage / Cloud Storage |
| Storage (Static) | User-uploaded static files | S3 + CloudFront / Blob + Front Door / GCS + CDN |

## Next Steps

1. Choose your cloud provider and follow the specific setup guide
2. Provision MongoDB Atlas cluster and create database user
3. Set up Redis instance
4. Configure cloud storage buckets/containers
5. Proceed to [Authentication Configuration](../authentication/auth0.md)

## Backup and Disaster Recovery

### MongoDB Backups
- MongoDB Atlas: Automatic continuous backups with point-in-time recovery
- Self-hosted: Implement automated backup strategy (mongodump, snapshots)
- Test restore procedures regularly

### Storage Backups
- All three storage buckets should have backup policies
- Recommended: Cross-region replication for production
- Versioning enabled on connectors bucket

### Redis Backups
- Not required - Redis data is ephemeral and can be rebuilt
- Can be safely restarted without data loss
