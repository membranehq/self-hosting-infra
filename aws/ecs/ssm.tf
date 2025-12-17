resource "aws_ssm_parameter" "secret" {
  name        = "/${var.environment}/integration-app/secret"
  description = "JWT token signing secret"
  type        = "SecureString"
  value       = random_password.secret.result

  tags = {
    Service = "api"
  }
}

resource "aws_ssm_parameter" "encryption_secret" {
  name        = "/${var.environment}/integration-app/encryption-secret"
  description = "Credentials encryption secret"
  type        = "SecureString"
  value       = random_password.encryption_secret.result

  tags = {
    Service = "api"
  }
}

resource "random_password" "secret" {
  length  = 32
  special = false
}

resource "random_password" "encryption_secret" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "harbor_pull" {
  name                    = "${var.environment}-harbor-pull-secret-v3"
  description             = "Harbor registry credentials for ECS image pulls"
  recovery_window_in_days = 0

  tags = {
    Service = "core"
  }
}

resource "aws_secretsmanager_secret_version" "harbor_pull" {
  secret_id = aws_secretsmanager_secret.harbor_pull.id
  secret_string = jsonencode({
    username = var.harbor_username
    password = var.harbor_password
  })
}

resource "aws_secretsmanager_secret" "mongo_uri" {
  name                    = "${var.environment}-mongo-uri-secret-v2"
  description             = "MongoDB connection URI"
  recovery_window_in_days = 0

  tags = {
    Service = "core"
  }
}

# MongoDB URI - supports DocumentDB, MongoDB EC2, or external MongoDB
locals {
  # DocumentDB URI (with TLS)
  docdb_uri = "mongodb://${var.docdb_username}:${var.docdb_password}@${try(aws_docdb_cluster.main[0].endpoint, "")}:27017/engine?tls=true&tlsCAFile=/etc/ssl/certs/rds-global-bundle.pem&replicaSet=rs0&readPreference=primary&retryWrites=false&authSource=admin&authMechanism=SCRAM-SHA-1"

  # MongoDB EC2 URI (without TLS for internal traffic)
  mongodb_ec2_uri = "mongodb://${var.mongodb_admin_username}:${var.mongodb_admin_password}@${try(aws_instance.mongodb[0].private_ip, "")}:27017/engine?authSource=admin"

  # Select the appropriate URI based on configuration
  mongo_uri_resolved = var.enable_mongodb_ec2 ? local.mongodb_ec2_uri : (var.enable_managed_database ? local.docdb_uri : var.mongo_uri)
}

resource "aws_secretsmanager_secret_version" "mongo_uri" {
  secret_id     = aws_secretsmanager_secret.mongo_uri.id
  secret_string = local.mongo_uri_resolved
}
