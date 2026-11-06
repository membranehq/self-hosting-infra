variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "AWS_REGION" {
  description = "AWS region"
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

  validation {
    condition     = var.betterauth_email_provider != "resend" || var.resend_api_key != null
    error_message = "resend_api_key is required when betterauth_email_provider is 'resend'."
  }
}

variable "betterauth_email_from" {
  description = "Sender address for BetterAuth emails, required when betterauth_email_provider is 'resend'"
  type        = string
  default     = null

  validation {
    condition     = var.betterauth_email_provider != "resend" || var.betterauth_email_from != null
    error_message = "betterauth_email_from is required when betterauth_email_provider is 'resend'."
  }
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
  default     = "integration-app"
}

variable "hosted_zone" {
  description = "Hosted Zone"
  type        = string
  default     = "int-membrane.com"
}

variable "create_hosted_zone" {
  description = "Create the Route53 hosted zone instead of using an existing one. When true, point your domain registrar at the zone's name servers (see hosted_zone_name_servers output) or certificate validation will fail."
  type        = bool
  default     = false
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  sensitive   = true
}

variable "mongo_uri" {
  description = "MongoDB URI"
  type        = string
  sensitive   = true
}

variable "image_tag" {
  description = "Could be 'latest' or some date '2025-09-23'"
  type        = string
  default     = "latest"
}

variable "api_image" {
  description = "path to api image in registry"
  type        = string
  default     = "harbor.integration.app/core/api"
}

variable "console_image" {
  description = "path to console image in registry"
  type        = string
  default     = "harbor.integration.app/core/console"
}

variable "ui_image" {
  description = "path to ui image in registry"
  type        = string
  default     = "harbor.integration.app/core/ui"
}

variable "custom_code_runner_image" {
  description = "path to custom code runner image in registry"
  type        = string
  default     = "harbor.integration.app/core/custom-code-runner"
}
