variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west3" # Frankfurt
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
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

variable "image_tag" {
  description = "Docker image tag for all Cloud Run services"
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
  default     = "gcp.int-membrane.com"
}

# Cloud Run Service - API
variable "api_cpu" {
  description = "CPU allocation for API service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "api_memory" {
  description = "Memory allocation for API service"
  type        = string
  default     = "2Gi"
}

variable "api_min_instances" {
  description = "Minimum number of instances for API"
  type        = number
  default     = 1
}

variable "api_max_instances" {
  description = "Maximum number of instances for API"
  type        = number
  default     = 10
}

# Cloud Run Service - UI
variable "ui_cpu" {
  description = "CPU allocation for UI service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "ui_memory" {
  description = "Memory allocation for UI service"
  type        = string
  default     = "512Mi"
}

variable "ui_min_instances" {
  description = "Minimum number of instances for UI"
  type        = number
  default     = 1
}

variable "ui_max_instances" {
  description = "Maximum number of instances for UI"
  type        = number
  default     = 10
}

# Cloud Run Service - Console
variable "console_cpu" {
  description = "CPU allocation for Console service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "console_memory" {
  description = "Memory allocation for Console service"
  type        = string
  default     = "512Mi"
}

variable "console_min_instances" {
  description = "Minimum number of instances for Console"
  type        = number
  default     = 1
}

variable "console_max_instances" {
  description = "Maximum number of instances for Console"
  type        = number
  default     = 10
}

# Cloud Run Service - Custom Code Runner
variable "runner_cpu" {
  description = "CPU allocation for Custom Code Runner service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "runner_memory" {
  description = "Memory allocation for Custom Code Runner service"
  type        = string
  default     = "512Mi"
}

variable "runner_min_instances" {
  description = "Minimum number of instances for Custom Code Runner"
  type        = number
  default     = 1
}

variable "runner_max_instances" {
  description = "Maximum number of instances for Custom Code Runner"
  type        = number
  default     = 10
}

# Cloud Run Service - Instant Tasks Worker
variable "instant_tasks_worker_cpu" {
  description = "CPU allocation for Instant Tasks Worker service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "instant_tasks_worker_memory" {
  description = "Memory allocation for Instant Tasks Worker service"
  type        = string
  default     = "1Gi"
}

variable "instant_tasks_worker_min_instances" {
  description = "Minimum number of instances for Instant Tasks Worker"
  type        = number
  default     = 2
}

variable "instant_tasks_worker_max_instances" {
  description = "Maximum number of instances for Instant Tasks Worker"
  type        = number
  default     = 10
}

# Cloud Run Service - Queued Tasks Worker
variable "queued_tasks_worker_cpu" {
  description = "CPU allocation for Queued Tasks Worker service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "queued_tasks_worker_memory" {
  description = "Memory allocation for Queued Tasks Worker service"
  type        = string
  default     = "1Gi"
}

variable "queued_tasks_worker_min_instances" {
  description = "Minimum number of instances for Queued Tasks Worker"
  type        = number
  default     = 2
}

variable "queued_tasks_worker_max_instances" {
  description = "Maximum number of instances for Queued Tasks Worker"
  type        = number
  default     = 10
}

# Cloud Run Service - Orchestrator
variable "orchestrator_cpu" {
  description = "CPU allocation for Orchestrator service (in vCPUs)"
  type        = string
  default     = "1"
}

variable "orchestrator_memory" {
  description = "Memory allocation for Orchestrator service"
  type        = string
  default     = "1Gi"
}

variable "orchestrator_min_instances" {
  description = "Minimum number of instances for Orchestrator"
  type        = number
  default     = 2
}

variable "orchestrator_max_instances" {
  description = "Maximum number of instances for Orchestrator"
  type        = number
  default     = 2
}

# Redis Configuration
variable "redis_tier" {
  description = "Redis service tier (BASIC or STANDARD_HA)"
  type        = string
  default     = "BASIC"
}

variable "redis_memory_size_gb" {
  description = "Redis memory size in GB"
  type        = number
  default     = 1
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "REDIS_7_0"
}
