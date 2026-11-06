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

# Container App - API
variable "api_cpu" {
  description = "CPU allocation for API container"
  type        = number
  default     = 1
}

variable "api_memory" {
  description = "Memory allocation for API container"
  type        = string
  default     = "2Gi"
}

variable "api_min_replicas" {
  description = "Minimum number of replicas for API"
  type        = number
  default     = 1
}

variable "api_max_replicas" {
  description = "Maximum number of replicas for API"
  type        = number
  default     = 1
}

# Container App - UI
variable "ui_cpu" {
  description = "CPU allocation for UI container"
  type        = number
  default     = 0.25
}

variable "ui_memory" {
  description = "Memory allocation for UI container"
  type        = string
  default     = "0.5Gi"
}

variable "ui_min_replicas" {
  description = "Minimum number of replicas for UI"
  type        = number
  default     = 1
}

variable "ui_max_replicas" {
  description = "Maximum number of replicas for UI"
  type        = number
  default     = 10
}

# Container App - Console
variable "console_cpu" {
  description = "CPU allocation for Console container"
  type        = number
  default     = 0.25
}

variable "console_memory" {
  description = "Memory allocation for Console container"
  type        = string
  default     = "0.5Gi"
}

variable "console_min_replicas" {
  description = "Minimum number of replicas for Console"
  type        = number
  default     = 1
}

variable "console_max_replicas" {
  description = "Maximum number of replicas for Console"
  type        = number
  default     = 10
}

# Container App - Custom Code Runner
variable "runner_cpu" {
  description = "CPU allocation for Custom Code Runner container"
  type        = number
  default     = 0.25
}

variable "runner_memory" {
  description = "Memory allocation for Custom Code Runner container"
  type        = string
  default     = "0.5Gi"
}

variable "runner_min_replicas" {
  description = "Minimum number of replicas for Custom Code Runner"
  type        = number
  default     = 1
}

variable "runner_max_replicas" {
  description = "Maximum number of replicas for Custom Code Runner"
  type        = number
  default     = 10
}

# Container App - Instant Tasks Worker
variable "instant_tasks_worker_cpu" {
  description = "CPU allocation for Instant Tasks Worker container"
  type        = number
  default     = 0.5
}

variable "instant_tasks_worker_memory" {
  description = "Memory allocation for Instant Tasks Worker container"
  type        = string
  default     = "1Gi"
}

variable "instant_tasks_worker_min_replicas" {
  description = "Minimum number of replicas for Instant Tasks Worker"
  type        = number
  default     = 2
}

variable "instant_tasks_worker_max_replicas" {
  description = "Maximum number of replicas for Instant Tasks Worker"
  type        = number
  default     = 10
}

# Container App - Queued Tasks Worker
variable "queued_tasks_worker_cpu" {
  description = "CPU allocation for Queued Tasks Worker container"
  type        = number
  default     = 0.5
}

variable "queued_tasks_worker_memory" {
  description = "Memory allocation for Queued Tasks Worker container"
  type        = string
  default     = "1Gi"
}

variable "queued_tasks_worker_min_replicas" {
  description = "Minimum number of replicas for Queued Tasks Worker"
  type        = number
  default     = 2
}

variable "queued_tasks_worker_max_replicas" {
  description = "Maximum number of replicas for Queued Tasks Worker"
  type        = number
  default     = 10
}

# Container App - Orchestrator
variable "orchestrator_cpu" {
  description = "CPU allocation for Orchestrator container"
  type        = number
  default     = 0.5
}

variable "orchestrator_memory" {
  description = "Memory allocation for Orchestrator container"
  type        = string
  default     = "1Gi"
}

variable "orchestrator_min_replicas" {
  description = "Minimum number of replicas for Orchestrator"
  type        = number
  default     = 2
}

variable "orchestrator_max_replicas" {
  description = "Maximum number of replicas for Orchestrator"
  type        = number
  default     = 2
}
