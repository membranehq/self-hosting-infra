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
