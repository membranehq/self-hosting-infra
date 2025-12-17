locals {
  docdb_resource_name = "integration-app-docdb-v8-${var.environment}"
}

resource "aws_docdb_subnet_group" "main" {
  count      = var.enable_managed_database ? 1 : 0
  name       = "docdb-subnet-group-${var.environment}"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Service = "docdb"
  }
}

# DocumentDB 8.0 Cluster
resource "aws_docdb_cluster" "main" {
  count                           = var.enable_managed_database ? 1 : 0
  cluster_identifier              = local.docdb_resource_name
  engine_version                  = "8.0.0"
  db_subnet_group_name            = aws_docdb_subnet_group.main[0].name
  vpc_security_group_ids          = [aws_security_group.docdb[0].id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main[0].name
  storage_encrypted               = true
  port                            = 27017
  master_username                 = var.docdb_username
  master_password                 = var.docdb_password
  deletion_protection             = false
  skip_final_snapshot             = true
  apply_immediately               = true

  tags = {
    Service = "api"
  }
}

resource "aws_docdb_cluster_instance" "main" {
  count              = var.enable_managed_database ? 1 : 0
  identifier         = "docdb-v8-${count.index}-${var.environment}"
  cluster_identifier = aws_docdb_cluster.main[0].id
  instance_class     = var.docdb_instance_class

  tags = {
    Service = "api"
  }
}

resource "aws_docdb_cluster_parameter_group" "main" {
  count       = var.enable_managed_database ? 1 : 0
  family      = "docdb8.0"
  name        = "${local.docdb_resource_name}-params"
  description = "docdb cluster parameter group for ${local.docdb_resource_name}"

  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = {
    Service = "docdb"
  }
}
