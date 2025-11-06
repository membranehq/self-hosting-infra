terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.51.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  required_version = ">= 1.11.3"
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}

# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.environment}-${var.project}-rg"
  location = var.location
  tags     = local.common_tags
}

# Data source to get current client configuration
data "azurerm_client_config" "current" {}

# Tags that will be applied to all resources
locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
  }

  # Domain name prefix based on environment
  # For prod: api.domain.com, for dev/stage: api.dev.domain.com
  domain_prefix = var.environment == "prod" ? "" : "${var.environment}."

  # Subdomain hostnames
  api_hostname     = "api.${local.domain_prefix}${var.domain_name}"
  ui_hostname      = "ui.${local.domain_prefix}${var.domain_name}"
  console_hostname = "console.${local.domain_prefix}${var.domain_name}"
  static_hostname  = "static.${local.domain_prefix}${var.domain_name}"
}
