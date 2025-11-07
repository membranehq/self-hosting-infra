# Artifact Registry repository for Harbor remote proxy
resource "google_artifact_registry_repository" "harbor_remote" {
  location      = var.region
  repository_id = "${var.environment}-${var.project}-harbor"
  description   = "Remote repository for Harbor registry (${var.harbor_host})"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"

  remote_repository_config {
    description = "Remote repository for Harbor at ${var.harbor_host}"

    docker_repository {
      custom_repository {
        uri = "https://${var.harbor_host}"
      }
    }

    upstream_credentials {
      username_password_credentials {
        username                = var.harbor_username
        password_secret_version = google_secret_manager_secret_version.harbor_password.id
      }
    }
  }

  labels = local.common_labels

  # Ensure IAM binding is created before the repository
  depends_on = [google_secret_manager_secret_iam_member.artifact_registry_harbor]
}

# Grant Cloud Run service accounts permission to pull from Artifact Registry
resource "google_artifact_registry_repository_iam_member" "api_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.api.email}"
}

resource "google_artifact_registry_repository_iam_member" "ui_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.ui.email}"
}

resource "google_artifact_registry_repository_iam_member" "console_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.console.email}"
}

resource "google_artifact_registry_repository_iam_member" "custom_code_runner_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.custom_code_runner.email}"
}

resource "google_artifact_registry_repository_iam_member" "instant_worker_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_artifact_registry_repository_iam_member" "queued_worker_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

resource "google_artifact_registry_repository_iam_member" "orchestrator_reader" {
  project    = var.project_id
  location   = google_artifact_registry_repository.harbor_remote.location
  repository = google_artifact_registry_repository.harbor_remote.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.orchestrator.email}"
}
