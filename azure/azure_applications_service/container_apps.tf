# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${var.environment}-membrane-env"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = azurerm_subnet.container_apps.id

  tags = local.common_tags
}

# Container Registry credentials are provided via variables

# API Container App
resource "azurerm_container_app" "api" {
  name                         = "${var.environment}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  registry {
    server               = var.harbor_host
    username             = var.harbor_username
    password_secret_name = "harbor-password"
  }

  secret {
    name  = "harbor-password"
    value = var.harbor_password
  }

  secret {
    name  = "jwt-secret"
    value = random_password.secret.result
  }

  secret {
    name  = "encryption-secret"
    value = random_password.encryption_secret.result
  }

  secret {
    name  = "mongo-uri"
    value = var.mongo_uri
  }

  template {
    container {
      name   = "api"
      image  = "${var.harbor_host}/core/api:${var.image_tag}"
      cpu    = 1
      memory = "2Gi"

      env {
        name  = "NODE_ENV"
        value = "production"
      }
      env {
        name  = "IS_WORKER"
        value = "1"
      }
      env {
        name  = "BASE_URI"
        value = "https://api.azure.int-membrane.com"
      }
      env {
        name  = "CUSTOM_CODE_RUNNER_URI"
        value = "https://${azurerm_container_app.custom_code_runner.latest_revision_fqdn}"
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
        name  = "AUTH0_CLIENT_SECRET"
        value = var.auth0_client_secret
      }
      env {
        name  = "TMP_S3_BUCKET"
        value = azurerm_storage_container.tmp.name
      }
      env {
        name  = "CONNECTORS_S3_BUCKET"
        value = azurerm_storage_container.connectors.name
      }
      env {
        name  = "STATIC_S3_BUCKET"
        value = "$web"
      }
      env {
        name  = "BASE_STATIC_URI"
        value = "https://static.azure.int-membrane.com"
      }
      env {
        name  = "REDIS_URI"
        value = "rediss://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_redis_cache.main.hostname}:6380"
      }
      env {
        name  = "PORT"
        value = "5000"
      }
      env {
        name  = "HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "AZURE_STORAGE_ACCOUNT_NAME"
        value = azurerm_storage_account.main.name
      }
      env {
        name  = "AZURE_STORAGE_CONNECTION_STRING"
        value = azurerm_storage_account.main.primary_connection_string
      }
      env {
        name        = "SECRET"
        secret_name = "jwt-secret"
      }
      env {
        name        = "ENCRYPTION_SECRET"
        secret_name = "encryption-secret"
      }
      env {
        name        = "MONGO_URI"
        secret_name = "mongo-uri"
      }
      env {
        name  = "STORAGE_PROVIDER"
        value = "abs"
      }
    }

    min_replicas = 1
    max_replicas = 1
  }

  ingress {
    external_enabled = true
    target_port      = 5000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags
}

# UI Container App
resource "azurerm_container_app" "ui" {
  name                         = "${var.environment}-ui"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = var.harbor_host
    username             = var.harbor_username
    password_secret_name = "harbor-password"
  }

  secret {
    name  = "harbor-password"
    value = var.harbor_password
  }

  template {
    container {
      name   = "ui"
      image  = "${var.harbor_host}/core/ui:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "NEXT_PUBLIC_ENGINE_URI"
        value = "https://api.azure.int-membrane.com"
      }
      env {
        name  = "PORT"
        value = "5000"
      }
    }

    min_replicas = 1
    max_replicas = 10
  }

  ingress {
    external_enabled = true
    target_port      = 5000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags
}

# Console Container App
resource "azurerm_container_app" "console" {
  name                         = "${var.environment}-console"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = var.harbor_host
    username             = var.harbor_username
    password_secret_name = "harbor-password"
  }

  secret {
    name  = "harbor-password"
    value = var.harbor_password
  }

  template {
    container {
      name   = "console"
      image  = "${var.harbor_host}/core/console:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "NODE_VERSION"
        value = "20.18.1"
      }
      env {
        name  = "NEXT_PUBLIC_BASE_URI"
        value = "https://console.azure.int-membrane.com"
      }
      env {
        name  = "NEXT_PUBLIC_AUTH0_DOMAIN"
        value = var.auth0_domain
      }
      env {
        name  = "NEXT_PUBLIC_ENGINE_API_URI"
        value = "https://api.azure.int-membrane.com"
      }
      env {
        name  = "NEXT_PUBLIC_ENGINE_UI_URI"
        value = "https://ui.azure.int-membrane.com"
      }
      env {
        name  = "NEXT_PUBLIC_AUTH0_CLIENT_ID"
        value = var.auth0_client_id
      }
      env {
        name  = "PORT"
        value = "5000"
      }
    }

    min_replicas = 1
    max_replicas = 10
  }

  ingress {
    external_enabled = true
    target_port      = 5000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags
}

# Custom Code Runner Container App
resource "azurerm_container_app" "custom_code_runner" {
  name                         = "${var.environment}-custom-code-runner"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  registry {
    server               = var.harbor_host
    username             = var.harbor_username
    password_secret_name = "harbor-password"
  }

  secret {
    name  = "harbor-password"
    value = var.harbor_password
  }

  template {
    container {
      name   = "custom-code-runner"
      image  = "${var.harbor_host}/core/custom-code-runner:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "PORT"
        value = "5000"
      }
    }

    min_replicas = 1
    max_replicas = 10
  }

  ingress {
    external_enabled = false
    target_port      = 5000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags
}

# Log Analytics Workspace for Container Apps
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.environment}-membrane-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Random passwords for secrets
resource "random_password" "secret" {
  length  = 32
  special = false
}

resource "random_password" "encryption_secret" {
  length  = 32
  special = false
}
