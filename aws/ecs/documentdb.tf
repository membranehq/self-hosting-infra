# It is a possible option to use AWS DocumentDB. But we support only MongoDB Atlas.
resource "aws_security_group" "docdb" {
  name        = "docdb-sg-${var.environment}"
  description = "Security group for DocumentDB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Service = "docdb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "docdb_ingress" {
  security_group_id            = aws_security_group.docdb.id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.docdb.id

  tags = {
    Service = "docdb"
  }
}

resource "aws_vpc_security_group_egress_rule" "docdb_egress" {
  security_group_id            = aws_security_group.docdb.id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.docdb.id

  tags = {
    Service = "docdb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "docdb_from_ecs" {
  security_group_id            = aws_security_group.docdb.id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.ecs_tasks.id

  tags = {
    Service = "docdb"
  }
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier              = local.docdb_resource_name
  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this.name
  storage_encrypted               = true
  port                            = 27017
  master_username                 = var.docdb_username
  master_password_wo              = ephemeral.random_password.docdb_master_password.result
  master_password_wo_version      = 10
  deletion_protection             = false
  skip_final_snapshot             = true
  apply_immediately               = true

  tags = {
    Service = "api"
  }
}

resource "aws_docdb_cluster_instance" "main" {
  count              = 1
  identifier         = "docdb-${count.index}-${var.environment}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium" # Smallest instance type for DocumentDB

  tags = {
    Service = "api"
  }
}

resource "aws_docdb_subnet_group" "main" {
  name       = "docdb-subnet-group-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Service = "docdb"
  }
}

resource "aws_docdb_cluster_parameter_group" "this" {
  family      = "docdb5.0"
  name        = local.docdb_resource_name
  description = "docdb cluster parameter group for ${local.docdb_resource_name}"
  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = {
    Service = "docdb"
  }
}

ephemeral "random_password" "docdb_master_password" {
  length  = 30
  special = false # avoid @ showing up in the password and breaking the URI
}

locals {
  docdb_resource_name = "integration-app-docdb-${var.environment}"

  tags = {
    Service = "docdb"
  }
}

resource "aws_secretsmanager_secret" "docdb" {
  name        = "${local.docdb_resource_name}-secret-new"
  description = "docdb credentials for integration app - ${var.environment}"
  tags = {
    Service = "api"
  }
}

resource "aws_secretsmanager_secret_version" "docdb" {
  secret_id                = aws_secretsmanager_secret.docdb.id
  secret_string_wo_version = 10
  secret_string_wo         = "mongodb://${var.docdb_username}:${ephemeral.random_password.docdb_master_password.result}@${aws_docdb_cluster.main.endpoint}:27017/integration-app?tls=true&tlsCAFile=%2Fetc%2Fssl%2Fcerts%2Frds-global-bundle.pem&authMechanism=SCRAM-SHA-1&replicaSet=rs0&retryWrites=false"
}

output "docdb_secret_arn" {
  value       = aws_secretsmanager_secret.docdb.arn
  description = "ARN of the Secrets Manager secret containing the DocumentDB URI"
}

output "docdb_endpoint" {
  value       = aws_docdb_cluster.main.endpoint
  description = "DocumentDB cluster endpoint"
}
