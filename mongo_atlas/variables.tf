# MongoDB Atlas API credentials
variable "mongodb_atlas_public_key" {
  description = "MongoDB Atlas public API key"
  type        = string
  sensitive   = true
}

variable "mongodb_atlas_private_key" {
  description = "MongoDB Atlas private API key"
  type        = string
  sensitive   = true
}

# Project configuration
variable "project_id" {
  description = "Existing MongoDB Atlas project ID"
  type        = string
}

# Cluster configuration
variable "cluster_name" {
  description = "Name of the MongoDB cluster"
  type        = string
  default     = "integration-app-cluster"
}

variable "provider_name" {
  description = "Cloud provider name (AWS, AZURE, GCP)"
  type        = string
  default     = "AZURE"
}

variable "provider_region" {
  description = "Cloud provider region (Atlas region names: GCP uses CENTRAL_US, EASTERN_US, WESTERN_US, etc.)"
  type        = string
  default     = "CENTRAL_US"

  validation {
    condition     = can(regex("^[A-Z0-9_]+$", var.provider_region))
    error_message = "Provider region must use MongoDB Atlas region naming format (e.g., CENTRAL_US, EASTERN_US, WESTERN_US, EUROPE_WEST_3)."
  }
}

variable "instance_size" {
  description = "Atlas instance size"
  type        = string
  default     = "M10"
}

variable "mongodb_version" {
  description = "MongoDB major version"
  type        = string
  default     = "7.0"
}

variable "num_nodes" {
  description = "Number of electable nodes per shard"
  type        = number
  default     = 1
}

variable "num_analytic_nodes" {
  description = "Number of analytics nodes per shard"
  type        = number
  default     = 0
}

variable "compute_min_instance_size" {
  description = "Minimum instance size for compute auto-scaling"
  type        = string
  default     = null
}

variable "compute_max_instance_size" {
  description = "Maximum instance size for compute auto-scaling"
  type        = string
  default     = "M30"
}
# Auto-scaling options
variable "auto_scaling_disk_enabled" {
  description = "Enable auto-scaling for disk"
  type        = bool
  default     = true
}

variable "auto_scaling_compute_enabled" {
  description = "Enable auto-scaling for compute"
  type        = bool
  default     = false
}

# Backup configuration
variable "cloud_backup_enabled" {
  description = "Enable cloud backup"
  type        = bool
  default     = false
}

# Database user configuration
variable "database_username" {
  description = "Database username"
  type        = string
  default     = "integration_app_user"
}

variable "database_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Network configuration
variable "ip_whitelist_cidr" {
  description = "CIDR block for IP whitelist (optional - leave empty to skip IP access list)"
  type        = string
  default     = null
}

# Environment
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}