variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "AWS_REGION" {
  description = "AWS region"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile name"
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

variable "docdb_username" {
  description = "DocumentDB username"
  type        = string
  default     = "integration_app"
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
