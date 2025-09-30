terraform {
  backend "kubernetes" {}
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.31.0"
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
}

locals {
  common_tags = {
    Environment = var.environment
    Project     = var.project
  }
}
