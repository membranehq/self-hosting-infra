# Service Accounts for Cloud Run services
# Creating dedicated service accounts allows for fine-grained IAM permissions

# API Service Account
resource "google_service_account" "api" {
  account_id   = "${local.service_name_prefix}-api"
  display_name = "Service account for API Cloud Run service"
  description  = "Used by the API Cloud Run service to access GCP resources"
}

# UI Service Account
resource "google_service_account" "ui" {
  account_id   = "${local.service_name_prefix}-ui"
  display_name = "Service account for UI Cloud Run service"
  description  = "Used by the UI Cloud Run service"
}

# Console Service Account
resource "google_service_account" "console" {
  account_id   = "${local.service_name_prefix}-console"
  display_name = "Service account for Console Cloud Run service"
  description  = "Used by the Console Cloud Run service"
}

# Custom Code Runner Service Account
resource "google_service_account" "custom_code_runner" {
  account_id   = "${local.service_name_prefix}-runner"
  display_name = "Service account for Custom Code Runner Cloud Run service"
  description  = "Used by the Custom Code Runner Cloud Run service"
}

# Instant Tasks Worker Service Account
resource "google_service_account" "instant_tasks_worker" {
  account_id   = "${local.service_name_prefix}-instant"
  display_name = "Service account for Instant Tasks Worker Cloud Run service"
  description  = "Used by the Instant Tasks Worker Cloud Run service"
}

# Queued Tasks Worker Service Account
resource "google_service_account" "queued_tasks_worker" {
  account_id   = "${local.service_name_prefix}-queued"
  display_name = "Service account for Queued Tasks Worker Cloud Run service"
  description  = "Used by the Queued Tasks Worker Cloud Run service"
}

# Orchestrator Service Account
resource "google_service_account" "orchestrator" {
  account_id   = "${local.service_name_prefix}-orch"
  display_name = "Service account for Orchestrator Cloud Run service"
  description  = "Used by the Orchestrator Cloud Run service"
}
