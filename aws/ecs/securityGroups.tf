resource "aws_security_group" "ecs_tasks" {
  name        = "${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  # NOTE: Do NOT add inline ingress/egress rules here!
  # Use standalone aws_vpc_security_group_*_rule resources instead
  # to avoid Terraform state drift.

  tags = {
    Service = "ecs"
  }

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

# ECS tasks can communicate with each other on port 5000
resource "aws_vpc_security_group_ingress_rule" "ecs_tasks_self" {
  security_group_id            = aws_security_group.ecs_tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.ecs_tasks.id

  tags = {
    Service = "ecs"
  }
}

# ECS tasks egress to anywhere
resource "aws_vpc_security_group_egress_rule" "ecs_tasks_all" {
  security_group_id = aws_security_group.ecs_tasks.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Service = "ecs"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.environment}-redis-sg"
  description = "Security group for Redis (ElastiCache)"
  vpc_id      = aws_vpc.main.id

  # NOTE: Do NOT add inline ingress/egress rules here!
  # Use standalone aws_vpc_security_group_*_rule resources instead
  # to avoid Terraform state drift.

  tags = {
    Service     = "redis"
    Environment = var.environment
  }

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

# Allow ECS tasks to connect to Redis
resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  security_group_id            = aws_security_group.redis.id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.ecs_tasks.id

  tags = {
    Service = "redis"
  }
}

# Redis egress
resource "aws_vpc_security_group_egress_rule" "redis_all" {
  security_group_id = aws_security_group.redis.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Service = "redis"
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Service = "alb"
  }
}

# Allow ALB to connect to ECS tasks
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs_tasks.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Service = "ecs"
  }
}

resource "aws_security_group" "docdb" {
  count       = var.enable_managed_database ? 1 : 0
  name        = "docdb-sg-${var.environment}"
  description = "Security group for DocumentDB"
  vpc_id      = aws_vpc.main.id

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
  referenced_security_group_id = aws_security_group.ecs_tasks.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Service = "docdb"
  }
}
