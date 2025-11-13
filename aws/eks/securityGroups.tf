resource "aws_security_group" "redis" {
  name        = "${var.environment}-redis-sg"
  description = "Security group for Redis (ElastiCache)"
  vpc_id      = var.vpc_id

  # Allow only from EKS cluster (TLS port)
  ingress {
    description     = "App Redis TLS port"
    from_port       = 6380
    to_port         = 6380
    protocol        = "tcp"
    security_groups = [data.aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id]
  }

  # Allow from VPC CIDR (all EKS nodes)
  ingress {
    description = "App Redis TLS port from VPC"
    from_port   = 6380
    to_port     = 6380
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service     = "redis"
    Environment = var.environment
  }
}
