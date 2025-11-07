# Storage bucket for temporary files
resource "google_storage_bucket" "tmp" {
  name          = "${var.project_id}-${var.environment}-${var.project}-tmp"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["*"]
    max_age_seconds = 3000
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  labels = local.common_labels
}

# Storage bucket for connectors
resource "google_storage_bucket" "connectors" {
  name          = "${var.project_id}-${var.environment}-${var.project}-connectors"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  labels = local.common_labels
}

# Storage bucket for static website
resource "google_storage_bucket" "static" {
  name          = "${var.project_id}-${var.environment}-${var.project}-static"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["*"]
    max_age_seconds = 3000
  }

  labels = local.common_labels
}

# Make static bucket publicly readable
resource "google_storage_bucket_iam_member" "static_public" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# Grant Cloud Run services access to storage buckets
resource "google_storage_bucket_iam_member" "api_tmp_access" {
  bucket = google_storage_bucket.tmp.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.api.email}"
}

resource "google_storage_bucket_iam_member" "api_connectors_access" {
  bucket = google_storage_bucket.connectors.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.api.email}"
}

resource "google_storage_bucket_iam_member" "api_static_access" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.api.email}"
}

# Worker access to buckets
resource "google_storage_bucket_iam_member" "instant_worker_tmp_access" {
  bucket = google_storage_bucket.tmp.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_storage_bucket_iam_member" "instant_worker_connectors_access" {
  bucket = google_storage_bucket.connectors.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_storage_bucket_iam_member" "queued_worker_tmp_access" {
  bucket = google_storage_bucket.tmp.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

resource "google_storage_bucket_iam_member" "queued_worker_connectors_access" {
  bucket = google_storage_bucket.connectors.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

resource "google_storage_bucket_iam_member" "orchestrator_tmp_access" {
  bucket = google_storage_bucket.tmp.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.orchestrator.email}"
}

resource "google_storage_bucket_iam_member" "orchestrator_connectors_access" {
  bucket = google_storage_bucket.connectors.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.orchestrator.email}"
}
