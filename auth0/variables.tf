variable "auth0_domain" {
  type        = string
  description = "The domain of the Auth0 tenant"
}

variable "auth0_client_id" {
  type        = string
  description = "The client ID of the Auth0 application"
}

variable "auth0_client_secret" {
  type        = string
  description = "The client secret of the Auth0 application"
}

variable "auth0_debug" {
  type        = bool
  description = "Whether to enable debug mode for the Auth0 provider"
}