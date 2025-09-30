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
  name        = "${var.environment}-harbor-pull-secret-new-2"
  description = "Harbor registry credentials for ECS image pulls"

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
  name        = "${var.environment}-mongo_uri-secret"
  description = "Harbor registry credentials for ECS image pulls"

  tags = {
    Service = "core"
  }
}

resource "aws_secretsmanager_secret_version" "mongo_uri" {
  secret_id = aws_secretsmanager_secret.mongo_uri.id
  secret_string = var.mongo_uri
}
