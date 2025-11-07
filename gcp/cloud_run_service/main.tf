terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  required_version = ">= 1.11.3"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Tags that will be applied to all resources
locals {
  common_labels = {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
  }

  # Domain name prefix based on environment
  # For prod: api.domain.com, for dev/stage: api.dev.domain.com
  domain_prefix = var.environment == "prod" ? "" : "${var.environment}."

  # Subdomain hostnames
  api_hostname     = "api.${local.domain_prefix}${var.domain_name}"
  ui_hostname      = "ui.${local.domain_prefix}${var.domain_name}"
  console_hostname = "console.${local.domain_prefix}${var.domain_name}"
  static_hostname  = "static.${local.domain_prefix}${var.domain_name}"

  # Cloud Run service names
  service_name_prefix = "${var.environment}-${var.project}"

  # Artifact Registry image path prefix
  # Images are pulled through Artifact Registry remote repository that proxies Harbor
  # The path should NOT include the upstream registry hostname - Artifact Registry handles the mapping
  image_path_prefix = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.harbor_remote.repository_id}/core"
}

# Random passwords for secrets
resource "random_password" "secret" {
  length  = 32
  special = false
}

resource "random_password" "encryption_secret" {
  length  = 32
  special = false
}
