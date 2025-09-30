resource "aws_security_group" "docdb" {
  count       = var.enable_managed_database ? 1 : 0
  name        = "docdb-sg-${var.environment}"
  description = "Security group for DocumentDB"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service = "docdb"
  }
}

# Allow DocumentDB to communicate with itself for replication
resource "aws_vpc_security_group_ingress_rule" "docdb_self" {
  count                        = var.enable_managed_database ? 1 : 0
  security_group_id            = aws_security_group.docdb[0].id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.docdb[0].id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service = "docdb"
  }
}

# Allow EKS cluster security group to access DocumentDB
resource "aws_vpc_security_group_ingress_rule" "docdb_from_eks_cluster" {
  count                        = var.enable_managed_database ? 1 : 0
  security_group_id            = aws_security_group.docdb[0].id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service = "docdb"
  }
}

# Allow access from VPC CIDR (all EKS nodes)
resource "aws_vpc_security_group_ingress_rule" "docdb_from_vpc" {
  count             = var.enable_managed_database ? 1 : 0
  security_group_id = aws_security_group.docdb[0].id
  ip_protocol       = "tcp"
  from_port         = 27017
  to_port           = 27017
  cidr_ipv4         = var.vpc_cidr

  tags = {
    Service = "docdb"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.environment}-redis-sg"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service = "redis"
  }
}

# Allow access from EKS cluster security group
resource "aws_vpc_security_group_ingress_rule" "redis_from_eks_cluster" {
  security_group_id            = aws_security_group.redis.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id

  tags = {
    Service = "redis"
  }
}

# Allow access from VPC CIDR (all EKS nodes)
resource "aws_vpc_security_group_ingress_rule" "redis_from_vpc" {
  security_group_id = aws_security_group.redis.id
  ip_protocol       = "tcp"
  from_port         = 6379
  to_port           = 6379
  cidr_ipv4         = var.vpc_cidr

  tags = {
    Service = "redis"
  }
}
