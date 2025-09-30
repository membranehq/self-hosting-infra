resource "aws_docdb_cluster" "main" {
  count = var.enable_managed_database ? 1 : 0
  cluster_identifier              = local.docdb_resource_name
  db_subnet_group_name            = aws_docdb_subnet_group.main[0].name
  vpc_security_group_ids          = [aws_security_group.docdb[0].id]
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.this[0].name
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
  identifier         = "docdb-${count.index}-${var.environment}"
  cluster_identifier = aws_docdb_cluster.main[0].id
  instance_class     = var.documentdb_instance_class

  tags = {
    Service = "api"
  }
}

resource "aws_docdb_subnet_group" "main" {
  count = var.enable_managed_database ? 1 : 0
  name       = "docdb-subnet-group-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = {
    Service = "docdb"
  }
}

resource "aws_docdb_cluster_parameter_group" "this" {
  count = var.enable_managed_database ? 1 : 0
  family      = var.docdb_family
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

locals {
  docdb_resource_name = "integration-app-docdb-${var.environment}"

  tags = {
    Service = "docdb"
  }
}
