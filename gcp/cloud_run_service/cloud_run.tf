# API Service
resource "google_cloud_run_v2_service" "api" {
  name               = "${local.service_name_prefix}-api"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.api.email

    scaling {
      min_instance_count = var.api_min_instances
      max_instance_count = var.api_max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${local.image_path_prefix}/api:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.api_cpu
          memory = var.api_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "IS_API"
        value = "1"
      }
      env {
        name  = "BASE_URI"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "CUSTOM_CODE_RUNNER_URI"
        value = google_cloud_run_v2_service.custom_code_runner.uri
      }
      env {
        name  = "AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "AUTH0_CLIENT_ID"
        value = var.auth0_client_id
      }
      env {
        name = "AUTH0_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth0_client_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "TMP_S3_BUCKET"
        value = google_storage_bucket.tmp.name
      }
      env {
        name  = "CONNECTORS_S3_BUCKET"
        value = google_storage_bucket.connectors.name
      }
      env {
        name  = "STATIC_S3_BUCKET"
        value = google_storage_bucket.static.name
      }
      env {
        name  = "BASE_STATIC_URI"
        value = "https://${local.static_hostname}"
      }
      env {
        name  = "REDIS_URI"
        value = "rediss://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:6379"
      }
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name = "SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "ENCRYPTION_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongo_uri.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "STORAGE_PROVIDER"
        value = "gcs"
      }
    }
  }

  labels = local.common_labels
}

# IAM binding to allow public access to API
resource "google_cloud_run_v2_service_iam_member" "api_public" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# UI Service
resource "google_cloud_run_v2_service" "ui" {
  name               = "${local.service_name_prefix}-ui"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.ui.email

    scaling {
      min_instance_count = var.ui_min_instances
      max_instance_count = var.ui_max_instances
    }

    containers {
      image = "${local.image_path_prefix}/ui:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.ui_cpu
          memory = var.ui_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }

      env {
        name  = "NEXT_PUBLIC_ENGINE_URI"
        value = "https://${local.api_hostname}"
      }
    }
  }

  labels = local.common_labels
}

resource "google_cloud_run_v2_service_iam_member" "ui_public" {
  name     = google_cloud_run_v2_service.ui.name
  location = google_cloud_run_v2_service.ui.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Console Service
resource "google_cloud_run_v2_service" "console" {
  name               = "${local.service_name_prefix}-console"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.console.email

    scaling {
      min_instance_count = var.console_min_instances
      max_instance_count = var.console_max_instances
    }

    containers {
      image = "${local.image_path_prefix}/console:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.console_cpu
          memory = var.console_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }

      env {
        name  = "NODE_VERSION"
        value = "20.18.1"
      }
      env {
        name  = "NEXT_PUBLIC_BASE_URI"
        value = "https://${local.console_hostname}"
      }
      env {
        name  = "NEXT_PUBLIC_AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "NEXT_PUBLIC_ENGINE_API_URI"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "NEXT_PUBLIC_ENGINE_UI_URI"
        value = "https://${local.ui_hostname}"
      }
      env {
        name  = "NEXT_PUBLIC_AUTH0_CLIENT_ID"
        value = var.auth0_client_id
      }
    }
  }

  labels = local.common_labels
}

resource "google_cloud_run_v2_service_iam_member" "console_public" {
  name     = google_cloud_run_v2_service.console.name
  location = google_cloud_run_v2_service.console.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Custom Code Runner Service
resource "google_cloud_run_v2_service" "custom_code_runner" {
  name               = "${local.service_name_prefix}-runner"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = google_service_account.custom_code_runner.email

    scaling {
      min_instance_count = var.runner_min_instances
      max_instance_count = var.runner_max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${local.image_path_prefix}/custom-code-runner:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.runner_cpu
          memory = var.runner_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }
    }
  }

  labels = local.common_labels
}

# Grant API service permission to invoke custom code runner
resource "google_cloud_run_v2_service_iam_member" "runner_api_invoker" {
  name     = google_cloud_run_v2_service.custom_code_runner.name
  location = google_cloud_run_v2_service.custom_code_runner.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.api.email}"
}

# Grant worker services permission to invoke custom code runner
resource "google_cloud_run_v2_service_iam_member" "runner_instant_worker_invoker" {
  name     = google_cloud_run_v2_service.custom_code_runner.name
  location = google_cloud_run_v2_service.custom_code_runner.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.instant_tasks_worker.email}"
}

resource "google_cloud_run_v2_service_iam_member" "runner_queued_worker_invoker" {
  name     = google_cloud_run_v2_service.custom_code_runner.name
  location = google_cloud_run_v2_service.custom_code_runner.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.queued_tasks_worker.email}"
}

# Instant Tasks Worker Service
resource "google_cloud_run_v2_service" "instant_tasks_worker" {
  name               = "${local.service_name_prefix}-instantworker"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = google_service_account.instant_tasks_worker.email

    scaling {
      min_instance_count = var.instant_tasks_worker_min_instances
      max_instance_count = var.instant_tasks_worker_max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${local.image_path_prefix}/api:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.instant_tasks_worker_cpu
          memory = var.instant_tasks_worker_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "IS_INSTANT_TASKS_WORKER"
        value = "1"
      }
      env {
        name  = "BASE_URI"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "BASE_URI_INTERNAL"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "CUSTOM_CODE_RUNNER_URI"
        value = google_cloud_run_v2_service.custom_code_runner.uri
      }
      env {
        name  = "AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "AUTH0_CLIENT_ID"
        value = var.auth0_client_id
      }
      env {
        name = "AUTH0_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth0_client_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "TMP_S3_BUCKET"
        value = google_storage_bucket.tmp.name
      }
      env {
        name  = "CONNECTORS_S3_BUCKET"
        value = google_storage_bucket.connectors.name
      }
      env {
        name  = "STATIC_S3_BUCKET"
        value = google_storage_bucket.static.name
      }
      env {
        name  = "BASE_STATIC_URI"
        value = "https://${local.static_hostname}"
      }
      env {
        name  = "REDIS_URI"
        value = "rediss://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:6379"
      }
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name = "SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "ENCRYPTION_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongo_uri.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "STORAGE_PROVIDER"
        value = "gcs"
      }
    }
  }

  labels = local.common_labels
}

# Queued Tasks Worker Service
resource "google_cloud_run_v2_service" "queued_tasks_worker" {
  name               = "${local.service_name_prefix}-queuedworker"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = google_service_account.queued_tasks_worker.email

    scaling {
      min_instance_count = var.queued_tasks_worker_min_instances
      max_instance_count = var.queued_tasks_worker_max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${local.image_path_prefix}/api:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.queued_tasks_worker_cpu
          memory = var.queued_tasks_worker_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "IS_QUEUED_TASKS_WORKER"
        value = "1"
      }
      env {
        name  = "BASE_URI"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "BASE_URI_INTERNAL"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "CUSTOM_CODE_RUNNER_URI"
        value = google_cloud_run_v2_service.custom_code_runner.uri
      }
      env {
        name  = "AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "AUTH0_CLIENT_ID"
        value = var.auth0_client_id
      }
      env {
        name = "AUTH0_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth0_client_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "TMP_S3_BUCKET"
        value = google_storage_bucket.tmp.name
      }
      env {
        name  = "CONNECTORS_S3_BUCKET"
        value = google_storage_bucket.connectors.name
      }
      env {
        name  = "STATIC_S3_BUCKET"
        value = google_storage_bucket.static.name
      }
      env {
        name  = "BASE_STATIC_URI"
        value = "https://${local.static_hostname}"
      }
      env {
        name  = "REDIS_URI"
        value = "rediss://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:6379"
      }
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name = "SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "ENCRYPTION_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongo_uri.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "STORAGE_PROVIDER"
        value = "gcs"
      }
      env {
        name  = "MAX_QUEUED_TASKS_MEMORY_MB"
        value = "1024"
      }
      env {
        name  = "MAX_QUEUED_TASKS_PROCESS_TIME_SECONDS"
        value = "3000"
      }
    }
  }

  labels = local.common_labels
}

# Orchestrator Service
resource "google_cloud_run_v2_service" "orchestrator" {
  name               = "${local.service_name_prefix}-orchestrator"
  location           = var.region
  ingress            = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  deletion_protection = false

  template {
    service_account = google_service_account.orchestrator.email

    scaling {
      min_instance_count = var.orchestrator_min_instances
      max_instance_count = var.orchestrator_max_instances
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.main.id
        subnetwork = google_compute_subnetwork.main.id
      }
      egress = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${local.image_path_prefix}/api:${var.image_tag}"

      ports {
        container_port = 5000
      }

      resources {
        limits = {
          cpu    = var.orchestrator_cpu
          memory = var.orchestrator_memory
        }
      }

      startup_probe {
        initial_delay_seconds = 0
        timeout_seconds       = 240
        period_seconds        = 10
        failure_threshold     = 3
        tcp_socket {
          port = 5000
        }
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "IS_ORCHESTRATOR"
        value = "1"
      }
      env {
        name  = "BASE_URI"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "BASE_URI_INTERNAL"
        value = "https://${local.api_hostname}"
      }
      env {
        name  = "CUSTOM_CODE_RUNNER_URI"
        value = google_cloud_run_v2_service.custom_code_runner.uri
      }
      env {
        name  = "AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "AUTH0_CLIENT_ID"
        value = var.auth0_client_id
      }
      env {
        name = "AUTH0_CLIENT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.auth0_client_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "TMP_S3_BUCKET"
        value = google_storage_bucket.tmp.name
      }
      env {
        name  = "CONNECTORS_S3_BUCKET"
        value = google_storage_bucket.connectors.name
      }
      env {
        name  = "STATIC_S3_BUCKET"
        value = google_storage_bucket.static.name
      }
      env {
        name  = "BASE_STATIC_URI"
        value = "https://${local.static_hostname}"
      }
      env {
        name  = "REDIS_URI"
        value = "rediss://:${google_redis_instance.main.auth_string}@${google_redis_instance.main.host}:6379"
      }
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name = "SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "ENCRYPTION_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.encryption_secret.secret_id
            version = "latest"
          }
        }
      }
      env {
        name = "MONGO_URI"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.mongo_uri.secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "STORAGE_PROVIDER"
        value = "gcs"
      }
    }
  }

  labels = local.common_labels
}
