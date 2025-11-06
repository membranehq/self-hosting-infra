variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "germanywestcentral"
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "client_id" {
  description = "Azure client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure client secret"
  type        = string
  sensitive   = true
}

variable "auth0_domain" {
  description = "Auth0 domain"
  type        = string
}

variable "auth0_client_id" {
  description = "Auth0 client ID"
  type        = string
}

variable "auth0_client_secret" {
  description = "Auth0 client secret"
  type        = string
  sensitive   = true
}

variable "mongo_uri" {
  description = "MongoDB URI"
  type        = string
  sensitive   = true
}

variable "harbor_username" {
  description = "Harbor username"
  type        = string
}

variable "harbor_password" {
  description = "Harbor password"
  type        = string
  sensitive   = true
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "membrane"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "membrane-rg"
}

variable "keyvault_suffix" {
  description = "Suffix to append to Key Vault name for uniqueness"
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Docker image tag for all container apps"
  type        = string
  default     = "latest"
}

variable "harbor_host" {
  description = "Harbor registry host"
  type        = string
  default     = "harbor.integration.app"
}

variable "domain_name" {
  description = "Base domain name for custom domains"
  type        = string
  default     = "azure.int-membrane.com"
}
