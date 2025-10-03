# Google Cloud Platform Resources

This guide covers GCP-specific resource provisioning for Membrane.

## Prerequisites

- Google Cloud Platform project with appropriate permissions
- gcloud CLI configured (optional, for manual setup)
- Terraform installed (recommended for infrastructure as code)

## Overview

Required GCP resources:
- **Cloud Storage Buckets** - Storage for temp files, connectors, and static assets
- **Cloud CDN** - CDN for serving static files (optional)
- **Memorystore for Redis** - Caching and job queue
- **Service Account** - Authentication for Membrane services
- **MongoDB Atlas** - Database (see [Cloud Resources](index.md#mongodb-atlas-setup-terraform-example))

## Service Account

Create a service account for Membrane services to access GCP resources.

```hcl
# Variables
variable "gcp_project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "gcp_region" {
  description = "GCP region (e.g., us-central1, europe-west1)"
  type        = string
  default     = "us-central1"
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for workload identity binding"
  type        = string
  default     = "membrane"
}

locals {
  common_labels = {
    environment = var.environment
    service     = "membrane"
    managed_by  = "terraform"
  }
}

# Create a service account for API service
resource "google_service_account" "api_service" {
  account_id   = "${var.project}-${var.environment}-api"
  display_name = "Membrane API Service Account for ${var.environment}"
  project      = var.gcp_project_id
}

# Grant storage admin permissions
resource "google_project_iam_member" "api_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# Grant token creator permission for signed URLs
resource "google_project_iam_member" "api_token_creator" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# Output service account email
output "service_account_email" {
  value       = google_service_account.api_service.email
  description = "Service account email for Membrane"
}
```

### Workload Identity (for GKE)

```hcl
# Allow Kubernetes service account to impersonate GCP service account
resource "google_service_account_iam_binding" "api_workload_identity" {
  service_account_id = google_service_account.api_service.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.kubernetes_namespace}/membrane-sa]"
  ]
}

# Output for Kubernetes service account annotation
output "workload_identity_annotation" {
  value       = "iam.gke.io/gcp-service-account: ${google_service_account.api_service.email}"
  description = "Annotation to add to Kubernetes service account"
}
```

## Cloud Storage

### Create Storage Buckets

```hcl
# Temporary files bucket
resource "google_storage_bucket" "tmp" {
  name          = "${var.project}-${var.environment}-tmp"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = true  # Allow deletion even if bucket contains objects

  uniform_bucket_level_access = true

  # Lifecycle rule to delete objects after 7 days
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  # Delete incomplete multipart uploads
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "AbortIncompleteMultipartUpload"
    }
  }

  versioning {
    enabled = false
  }

  labels = local.common_labels
}

# Connectors bucket
resource "google_storage_bucket" "connectors" {
  name          = "${var.project}-${var.environment}-connectors"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = false  # Prevent accidental deletion

  uniform_bucket_level_access = true

  # Enable versioning for code safety
  versioning {
    enabled = true
  }

  # Lifecycle rule to delete old versions after 30 days
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  labels = local.common_labels
}

# Static content bucket
resource "google_storage_bucket" "static" {
  name          = "${var.project}-${var.environment}-static"
  location      = var.gcp_region
  project       = var.gcp_project_id
  force_destroy = var.environment != "prod"

  uniform_bucket_level_access = true

  # Website configuration
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  # CORS configuration
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = false
  }

  labels = local.common_labels
}

# Make static bucket publicly accessible for CDN
resource "google_storage_bucket_iam_member" "static_public_access" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Output bucket names
output "tmp_bucket_name" {
  value       = google_storage_bucket.tmp.name
  description = "Temporary files bucket name"
}

output "connectors_bucket_name" {
  value       = google_storage_bucket.connectors.name
  description = "Connectors bucket name"
}

output "static_bucket_name" {
  value       = google_storage_bucket.static.name
  description = "Static files bucket name"
}
```

## Cloud CDN (Optional)

Configure Cloud CDN with Cloud Load Balancer to serve static files.

### Reserve Global IP Address

```hcl
variable "enable_cdn" {
  description = "Enable Cloud CDN for static files"
  type        = bool
  default     = true
}

# Reserve a global static IP for the load balancer
resource "google_compute_global_address" "cdn_ip" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-ip"
  project = var.gcp_project_id
}
```

### Backend Bucket

```hcl
# Backend bucket for serving static content
resource "google_compute_backend_bucket" "static_backend" {
  count = var.enable_cdn ? 1 : 0

  name        = "${var.project}-${var.environment}-static-backend"
  description = "Backend bucket for static content"
  bucket_name = google_storage_bucket.static.name
  project     = var.gcp_project_id
  enable_cdn  = true

  # CDN policy
  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    client_ttl        = 3600    # 1 hour
    default_ttl       = 3600    # 1 hour
    max_ttl           = 86400   # 1 day
    negative_caching  = true
    serve_while_stale = 86400

    negative_caching_policy {
      code = 404
      ttl  = 120
    }

    cache_key_policy {
      query_string_whitelist = []
    }
  }

  compression_mode = "AUTOMATIC"
}
```

### URL Map and SSL Certificate

```hcl
variable "domain_name" {
  description = "Domain name for static CDN (e.g., example.com)"
  type        = string
}

# URL map for routing
resource "google_compute_url_map" "cdn_url_map" {
  count = var.enable_cdn ? 1 : 0

  name            = "${var.project}-${var.environment}-cdn-url-map"
  default_service = google_compute_backend_bucket.static_backend[0].id
  project         = var.gcp_project_id

  host_rule {
    hosts        = ["static.${var.domain_name}"]
    path_matcher = "static-paths"
  }

  path_matcher {
    name            = "static-paths"
    default_service = google_compute_backend_bucket.static_backend[0].id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_bucket.static_backend[0].id
    }
  }
}

# Managed SSL certificate
resource "google_compute_managed_ssl_certificate" "cdn_cert" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-cert"
  project = var.gcp_project_id

  managed {
    domains = ["static.${var.domain_name}"]
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "cdn_https_proxy" {
  count = var.enable_cdn ? 1 : 0

  name             = "${var.project}-${var.environment}-cdn-https-proxy"
  url_map          = google_compute_url_map.cdn_url_map[0].id
  ssl_certificates = [google_compute_managed_ssl_certificate.cdn_cert[0].id]
  project          = var.gcp_project_id
}

# HTTP proxy for redirect to HTTPS
resource "google_compute_target_http_proxy" "cdn_http_proxy" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-http-proxy"
  url_map = google_compute_url_map.cdn_http_redirect[0].id
  project = var.gcp_project_id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "cdn_http_redirect" {
  count = var.enable_cdn ? 1 : 0

  name    = "${var.project}-${var.environment}-cdn-http-redirect"
  project = var.gcp_project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}
```

### Global Forwarding Rules

```hcl
# Global forwarding rule for HTTPS
resource "google_compute_global_forwarding_rule" "cdn_https_forwarding" {
  count = var.enable_cdn ? 1 : 0

  name                  = "${var.project}-${var.environment}-cdn-https-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.cdn_https_proxy[0].id
  ip_address            = google_compute_global_address.cdn_ip[0].id
  project               = var.gcp_project_id
}

# Global forwarding rule for HTTP
resource "google_compute_global_forwarding_rule" "cdn_http_forwarding" {
  count = var.enable_cdn ? 1 : 0

  name                  = "${var.project}-${var.environment}-cdn-http-forwarding"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.cdn_http_proxy[0].id
  ip_address            = google_compute_global_address.cdn_ip[0].id
  project               = var.gcp_project_id
}

# Output CDN IP
output "cdn_ip_address" {
  value       = var.enable_cdn ? google_compute_global_address.cdn_ip[0].address : null
  description = "CDN global IP address"
}
```

## DNS Configuration

```hcl
# DNS managed zone
resource "google_dns_managed_zone" "main" {
  name        = replace(var.domain_name, ".", "-")
  dns_name    = "${var.domain_name}."
  description = "${var.project} ${var.environment} DNS zone"
  project     = var.gcp_project_id

  labels = local.common_labels

  dnssec_config {
    state = "on"
  }
}

# DNS record for static content CDN
resource "google_dns_record_set" "static_cdn" {
  count = var.enable_cdn ? 1 : 0

  name         = "static.${google_dns_managed_zone.main.dns_name}"
  managed_zone = google_dns_managed_zone.main.name
  type         = "A"
  ttl          = 300
  project      = var.gcp_project_id

  rrdatas = [google_compute_global_address.cdn_ip[0].address]
}

# CAA record for SSL certificate issuance
resource "google_dns_record_set" "caa" {
  name         = google_dns_managed_zone.main.dns_name
  managed_zone = google_dns_managed_zone.main.name
  type         = "CAA"
  ttl          = 300
  project      = var.gcp_project_id

  rrdatas = [
    "0 issue \"pki.goog\"",
    "0 issue \"letsencrypt.org\""
  ]
}

# Output DNS name servers
output "dns_name_servers" {
  value       = google_dns_managed_zone.main.name_servers
  description = "DNS name servers to configure at your domain registrar"
}

output "static_cdn_url" {
  value       = var.enable_cdn ? "https://static.${var.domain_name}" : "https://storage.googleapis.com/${google_storage_bucket.static.name}"
  description = "Static files CDN URL (use for BASE_STATIC_URI)"
}
```

## Redis

### Memorystore for Redis

```hcl
variable "vpc_network" {
  description = "VPC network name for Redis"
  type        = string
}

# Create Redis instance
resource "google_redis_instance" "main" {
  name               = "${var.project}-${var.environment}-redis"
  project            = var.gcp_project_id
  region             = var.gcp_region
  tier               = "STANDARD_HA"  # BASIC or STANDARD_HA
  memory_size_gb     = 5
  redis_version      = "REDIS_6_X"
  display_name       = "Membrane Redis ${var.environment}"
  authorized_network = var.vpc_network

  # Redis configuration
  redis_configs = {
    # No persistence needed - Membrane uses Redis as cache only
    "maxmemory-policy" = "allkeys-lru"
  }

  # Maintenance window
  maintenance_policy {
    weekly_maintenance_window {
      day = "SUNDAY"
      start_time {
        hours   = 5
        minutes = 0
      }
    }
  }

  # Enable transit encryption
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  auth_enabled            = true

  labels = local.common_labels
}

# Output Redis connection details
output "redis_host" {
  value       = google_redis_instance.main.host
  description = "Redis host IP"
}

output "redis_port" {
  value       = google_redis_instance.main.port
  description = "Redis port"
}

output "redis_auth_string" {
  value       = google_redis_instance.main.auth_string
  sensitive   = true
  description = "Redis authentication string"
}

output "redis_connection_string" {
  value = format(
    "rediss://:%s@%s:%d",
    google_redis_instance.main.auth_string,
    google_redis_instance.main.host,
    google_redis_instance.main.port
  )
  sensitive   = true
  description = "Redis connection string (use for REDIS_URI)"
}
```

### VPC Peering (for Memorystore)

Memorystore requires VPC peering. Ensure your VPC has allocated IP ranges for Google services:

```hcl
# Allocate IP range for Google services
resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.project}-${var.environment}-google-services"
  project       = var.gcp_project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network
}

# Create private VPC connection
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}
```

## MongoDB

**Recommended:** Use [MongoDB Atlas](index.md#mongodb-atlas-setup-terraform-example) (managed service).

For GCP-specific MongoDB Atlas configuration, select "GCP" as the provider in the Atlas cluster configuration.

## Environment Variables Summary

After provisioning GCP resources, configure these environment variables:

```bash
# Storage
STORAGE_PROVIDER=gcs
GOOGLE_CLOUD_PROJECT_ID=my-gcp-project
# Optional: Path to service account key file (not needed with Workload Identity)
# GOOGLE_CLOUD_KEYFILE=/path/to/keyfile.json

# Bucket names
TMP_STORAGE_BUCKET=myproject-prod-tmp
CONNECTORS_STORAGE_BUCKET=myproject-prod-connectors
STATIC_STORAGE_BUCKET=myproject-prod-static
BASE_STATIC_URI=https://static.example.com

# Redis
REDIS_URI=rediss://:<auth-string>@<redis-host>:6378

# MongoDB (from Atlas)
MONGO_URI=mongodb+srv://username:password@cluster.mongodb.net/membrane
```

## Using Workload Identity (GKE)

When deploying on GKE with Workload Identity:

1. Annotate your Kubernetes service account:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: membrane-sa
  namespace: membrane
  annotations:
    iam.gke.io/gcp-service-account: <service-account-email>
```

2. Environment variables for storage:
```bash
STORAGE_PROVIDER=gcs
GOOGLE_CLOUD_PROJECT_ID=my-gcp-project
# Do not set GOOGLE_CLOUD_KEYFILE - Workload Identity handles authentication
```

## Next Steps

1. Verify all resources are provisioned correctly
2. Configure [Authentication](../authentication/auth0.md)
3. Proceed to [Deployment](../deployment/services.md)
