output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

# Cloud Run Service URLs
output "cloud_run_urls" {
  description = "Cloud Run service URLs"
  value = {
    api                  = google_cloud_run_v2_service.api.uri
    ui                   = google_cloud_run_v2_service.ui.uri
    console              = google_cloud_run_v2_service.console.uri
    custom_code_runner   = google_cloud_run_v2_service.custom_code_runner.uri
    instant_tasks_worker = google_cloud_run_v2_service.instant_tasks_worker.uri
    queued_tasks_worker  = google_cloud_run_v2_service.queued_tasks_worker.uri
    orchestrator         = google_cloud_run_v2_service.orchestrator.uri
  }
}

# Custom Domain URLs
output "custom_domain_urls" {
  description = "Custom domain URLs"
  value = {
    api     = "https://${local.api_hostname}"
    ui      = "https://${local.ui_hostname}"
    console = "https://${local.console_hostname}"
    static  = "https://${local.static_hostname}"
  }
}

# Load Balancer IP Addresses
output "load_balancer_ips" {
  description = "Load Balancer IP addresses"
  value = {
    api     = google_compute_global_address.api.address
    ui      = google_compute_global_address.ui.address
    console = google_compute_global_address.console.address
    static  = google_compute_global_address.static.address
  }
}

# Storage Bucket Names
output "storage_buckets" {
  description = "Storage bucket names"
  value = {
    tmp        = google_storage_bucket.tmp.name
    connectors = google_storage_bucket.connectors.name
    static     = google_storage_bucket.static.name
  }
}

# Artifact Registry
output "artifact_registry" {
  description = "Artifact Registry remote repository information"
  value = {
    repository_id = google_artifact_registry_repository.harbor_remote.repository_id
    location      = google_artifact_registry_repository.harbor_remote.location
    format        = google_artifact_registry_repository.harbor_remote.format
    mode          = google_artifact_registry_repository.harbor_remote.mode
    image_prefix  = local.image_path_prefix
  }
}

# Redis Connection
output "redis_host" {
  description = "Redis instance host"
  value       = google_redis_instance.main.host
}

output "redis_port" {
  description = "Redis instance port"
  value       = google_redis_instance.main.port
}

output "redis_connection_string" {
  description = "Redis connection string (rediss://)"
  value       = "rediss://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:6379"
  sensitive   = true
}

# DNS Configuration
output "dns_zone_name_servers" {
  description = "Cloud DNS name servers"
  value       = google_dns_managed_zone.main.name_servers
}

output "dns_zone_name" {
  description = "Cloud DNS zone name"
  value       = google_dns_managed_zone.main.name
}

# Network Information
output "vpc_network" {
  description = "VPC network name"
  value       = google_compute_network.main.name
}

output "vpc_subnet" {
  description = "VPC subnet name"
  value       = google_compute_subnetwork.main.name
}

# Cloud NAT IP Addresses (for MongoDB Atlas whitelisting)
output "cloud_nat_ips" {
  description = "Static IP addresses used by Cloud NAT for outbound traffic - add these to MongoDB Atlas IP whitelist"
  value       = google_compute_address.nat_ip[*].address
}

# Secret Manager
output "secret_ids" {
  description = "Secret Manager secret IDs"
  value = {
    jwt_secret          = google_secret_manager_secret.jwt_secret.secret_id
    encryption_secret   = google_secret_manager_secret.encryption_secret.secret_id
    mongo_uri           = google_secret_manager_secret.mongo_uri.secret_id
    auth0_client_secret = google_secret_manager_secret.auth0_client_secret.secret_id
    harbor_password     = google_secret_manager_secret.harbor_password.secret_id
  }
}

# SSL Certificate Status
output "ssl_certificates" {
  description = "Managed SSL certificate names and status"
  value = {
    api = {
      name   = google_compute_managed_ssl_certificate.api.name
      domains = google_compute_managed_ssl_certificate.api.managed[0].domains
    }
    ui = {
      name   = google_compute_managed_ssl_certificate.ui.name
      domains = google_compute_managed_ssl_certificate.ui.managed[0].domains
    }
    console = {
      name   = google_compute_managed_ssl_certificate.console.name
      domains = google_compute_managed_ssl_certificate.console.managed[0].domains
    }
    static = {
      name   = google_compute_managed_ssl_certificate.static.name
      domains = google_compute_managed_ssl_certificate.static.managed[0].domains
    }
  }
}

# Instructions
output "deployment_instructions" {
  description = "Next steps after deployment"
  value = <<-EOT

  Deployment Complete!

  Next Steps:
  1. Update your domain's nameservers to point to:
     ${join("\n     ", google_dns_managed_zone.main.name_servers)}

  2. Wait for DNS propagation (can take up to 48 hours)

  3. SSL certificates will be automatically provisioned after DNS is configured
     (this can take 15-60 minutes)

  4. Access your services at:
     - API:     https://${local.api_hostname}
     - UI:      https://${local.ui_hostname}
     - Console: https://${local.console_hostname}
     - Static:  https://${local.static_hostname}

  5. Monitor certificate provisioning:
     gcloud compute ssl-certificates describe ${google_compute_managed_ssl_certificate.api.name} --global

  EOT
}
