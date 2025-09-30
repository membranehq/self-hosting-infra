terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.40.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  required_version = ">= 1.11.3"
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

locals {
  common_labels = {
    environment = lower(var.environment)
    project     = lower(var.project)
    managed-by  = "terraform"
  }
}
