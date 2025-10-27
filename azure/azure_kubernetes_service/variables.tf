variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "test"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "integration-app"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "integration-app-rg"
}

variable "dns_zone_name" {
  description = ""
  type        = string
  default     = "azure.int-membrane.com"
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "kubernetes_namespace" {
  description = "K8S namespace"
  type        = string
}

variable "aks_vnet_name" {
  description = "Name of the AKS VNet (if not provided, will attempt to discover)"
  type        = string
  default     = null
}

variable "private_endpoint_subnet_cidr" {
  description = "CIDR block for private endpoints subnet. If not provided, will calculate dynamically."
  type        = string
  default     = null
}
