# Create a Google Service Account for the API service
resource "google_service_account" "api_service" {
  account_id   = "${var.project}-${var.environment}-api"
  display_name = "API Service Account for ${var.environment}"
  project      = var.gcp_project_id
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "api_storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# Grant token creator permission for storage signed URLs
resource "google_project_iam_member" "api_token_creator" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.api_service.email}"
}

# Allow the Kubernetes service account to impersonate the Google service account
resource "google_service_account_iam_binding" "api_workload_identity" {
  service_account_id = google_service_account.api_service.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.kubernetes_namespace}/integration-app]"
  ]
}

# Output the service account email for use in Helm values
output "api_service_account_email" {
  value = google_service_account.api_service.email
}

# Create a Google Service Account for External DNS
resource "google_service_account" "external_dns" {
  account_id   = "external-dns-${var.environment}"
  display_name = "External DNS Service Account for ${var.environment}"
  project      = var.gcp_project_id
}

# Grant DNS admin permissions to External DNS service account
resource "google_project_iam_member" "external_dns_admin" {
  project = var.gcp_project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns.email}"
}

# Allow the External DNS Kubernetes service account to impersonate the Google service account
resource "google_service_account_iam_binding" "external_dns_workload_identity" {
  service_account_id = google_service_account.external_dns.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.gcp_project_id}.svc.id.goog[${var.kubernetes_namespace}/external-dns]"
  ]
}

