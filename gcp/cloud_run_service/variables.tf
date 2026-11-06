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

variable "instance_token" {
  description = "Self-hosting instance token (sht_...), generated in Membrane console organization settings"
  type        = string
  sensitive   = true
}

variable "betterauth_email_provider" {
  description = "BetterAuth email delivery: 'resend' (set resend_api_key and betterauth_email_from) or 'webhook' (configure webhooks in MongoDB)"
  type        = string

  validation {
    condition     = contains(["resend", "webhook"], var.betterauth_email_provider)
    error_message = "betterauth_email_provider must be 'resend' or 'webhook'."
  }
}

variable "resend_api_key" {
  description = "Resend API key, required when betterauth_email_provider is 'resend'"
  type        = string
  sensitive   = true
  default     = null
}

variable "betterauth_email_from" {
  description = "Sender address for BetterAuth emails, required when betterauth_email_provider is 'resend'"
  type        = string
  default     = null
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
