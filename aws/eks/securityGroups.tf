resource "aws_security_group" "redis" {
  name        = "${var.environment}-redis-sg"
  description = "Security group for Redis (ElastiCache)"
  vpc_id      = aws_vpc.main.id

  # Allow only from EKS cluster (TLS port)
  ingress {
    description     = "App Redis TLS port"
    from_port       = 6380
    to_port         = 6380
    protocol        = "tcp"
    security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
  }

  # Allow from EKS node group (all EKS nodes)
  ingress {
    description     = "App Redis TLS port from nodes"
    from_port       = 6380
    to_port         = 6380
    protocol        = "tcp"
    security_groups = [aws_security_group.node_group.id]
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
    Component   = "security-group"
  }
}
