# Secret Manager - JWT Secret
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${local.service_name_prefix}-jwt-secret"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.secret.result
}

# Secret Manager - Encryption Secret
resource "google_secret_manager_secret" "encryption_secret" {
  secret_id = "${local.service_name_prefix}-encryption-secret"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "encryption_secret" {
  secret      = google_secret_manager_secret.encryption_secret.id
  secret_data = random_password.encryption_secret.result
}

# Secret Manager - MongoDB URI
resource "google_secret_manager_secret" "mongo_uri" {
  secret_id = "${local.service_name_prefix}-mongo-uri"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "mongo_uri" {
  secret      = google_secret_manager_secret.mongo_uri.id
  secret_data = var.mongo_uri
}

# Secret Manager - Auth0 Client Secret
resource "google_secret_manager_secret" "auth0_client_secret" {
  secret_id = "${local.service_name_prefix}-auth0-client-secret"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "auth0_client_secret" {
  secret      = google_secret_manager_secret.auth0_client_secret.id
  secret_data = var.auth0_client_secret
}

# Secret Manager - Harbor Password
# Artifact Registry requires the password to be stored directly (not as JSON)
resource "google_secret_manager_secret" "harbor_password" {
  secret_id = "${local.service_name_prefix}-harbor-password"

  replication {
    auto {}
  }

  labels = local.common_labels
}

resource "google_secret_manager_secret_version" "harbor_password" {
  secret      = google_secret_manager_secret.harbor_password.id
  secret_data = var.harbor_password
}

# Grant Artifact Registry service account access to Harbor password
# This is required for the remote repository to authenticate with Harbor
data "google_project" "current" {}

resource "google_secret_manager_secret_iam_member" "artifact_registry_harbor" {
  secret_id = google_secret_manager_secret.harbor_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
}

# Grant Cloud Run services access to secrets
# API Service
resource "google_secret_manager_secret_iam_member" "api_jwt_secret" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_encryption_secret" {
  secret_id = google_secret_manager_secret.encryption_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_mongo_uri" {
  secret_id = google_secret_manager_secret.mongo_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_auth0_client_secret" {
  secret_id = google_secret_manager_secret.auth0_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# Instant Tasks Worker
resource "google_secret_manager_secret_iam_member" "instant_worker_jwt_secret" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_secret_manager_secret_iam_member" "instant_worker_encryption_secret" {
  secret_id = google_secret_manager_secret.encryption_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_secret_manager_secret_iam_member" "instant_worker_mongo_uri" {
  secret_id = google_secret_manager_secret.mongo_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_secret_manager_secret_iam_member" "instant_worker_auth0_client_secret" {
  secret_id = google_secret_manager_secret.auth0_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

# Queued Tasks Worker
resource "google_secret_manager_secret_iam_member" "queued_worker_jwt_secret" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

resource "google_secret_manager_secret_iam_member" "queued_worker_encryption_secret" {
  secret_id = google_secret_manager_secret.encryption_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

resource "google_secret_manager_secret_iam_member" "queued_worker_mongo_uri" {
  secret_id = google_secret_manager_secret.mongo_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

resource "google_secret_manager_secret_iam_member" "queued_worker_auth0_client_secret" {
  secret_id = google_secret_manager_secret.auth0_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

# Orchestrator
resource "google_secret_manager_secret_iam_member" "orchestrator_jwt_secret" {
  secret_id = google_secret_manager_secret.jwt_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.orchestrator.email}"
}

resource "google_secret_manager_secret_iam_member" "orchestrator_encryption_secret" {
  secret_id = google_secret_manager_secret.encryption_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.orchestrator.email}"
}

resource "google_secret_manager_secret_iam_member" "orchestrator_mongo_uri" {
  secret_id = google_secret_manager_secret.mongo_uri.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.orchestrator.email}"
}

resource "google_secret_manager_secret_iam_member" "orchestrator_auth0_client_secret" {
  secret_id = google_secret_manager_secret.auth0_client_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.orchestrator.email}"
}
