# Temporary files bucket
resource "google_storage_bucket" "tmp" {
  name     = "${var.project}-${var.environment}-tmp"
  location = var.gcp_region
  project  = var.gcp_project_id

  # Force destroy even if bucket contains objects
  force_destroy = true

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Lifecycle rule to delete objects after 7 days
  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  # Versioning
  versioning {
    enabled = false
  }

  # Labels
  labels = local.common_labels
}

# Connectors bucket
resource "google_storage_bucket" "connectors" {
  name     = "${var.project}-${var.environment}-connectors"
  location = var.gcp_region
  project  = var.gcp_project_id

  # Prevent accidental deletion
  force_destroy = false

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Versioning for code safety
  versioning {
    enabled = true
  }

  # Lifecycle rule to delete old versions after 30 days
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # Labels
  labels = local.common_labels
}

# Static content bucket
resource "google_storage_bucket" "static" {
  name     = "${var.project}-${var.environment}-static"
  location = var.gcp_region
  project  = var.gcp_project_id

  # Force destroy for development environments
  force_destroy = var.environment != "prod"

  # Uniform bucket-level access
  uniform_bucket_level_access = true

  # Website configuration
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  # CORS configuration
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "OPTIONS"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # Versioning
  versioning {
    enabled = false
  }

  # Labels
  labels = local.common_labels
}

# Make static bucket publicly accessible for CDN
resource "google_storage_bucket_iam_member" "static_public_access" {
  bucket = google_storage_bucket.static.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
