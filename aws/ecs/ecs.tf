locals {
  # Use the configuration endpoint for cluster mode enabled Redis with TLS on port 6380
  redis_configuration_endpoint = "rediss://${aws_elasticache_replication_group.redis.configuration_endpoint_address}:6380"
}

resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Service = "core"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.environment}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.api_image}:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "BASE_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_WEBHOOKS_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_OAUTH_CALLBACK_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "CUSTOM_CODE_RUNNER_URI", value = "http://custom-code-runner.${var.environment}.local:5000" },
        { name = "OPENAI_API_KEY", value = var.openai_api_key },
        { name = "ANTHROPIC_API_KEY", value = var.anthropic_api_key },
        { name = "AUTH0_DOMAIN", value = var.auth0_domain },
        { name = "AUTH0_CLIENT_ID", value = var.auth0_client_id },
        { name = "AUTH0_CLIENT_SECRET", value = var.auth0_client_secret },
        { name = "COPILOT_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "TMP_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "CONNECTORS_S3_BUCKET", value = aws_s3_bucket.connectors.id },
        { name = "STATIC_S3_BUCKET", value = aws_s3_bucket.static.id },
        { name = "BASE_STATIC_URI", value = "https://${aws_route53_record.static.name}" },
        { name = "REDIS_CLUSTER_URI_1", value = local.redis_configuration_endpoint },
        { name = "REDIS_DISABLE_TLS_VERIFICATION", value = "true" },
        { name = "PORT", value = "5000" },
        { name = "HOST", value = "0.0.0.0" },
        { name = "AWS_REGION", value = var.AWS_REGION },
      ]
      secrets = [
        { name = "SECRET", valueFrom = aws_ssm_parameter.secret.arn },
        { name = "ENCRYPTION_SECRET", valueFrom = aws_ssm_parameter.encryption_secret.arn },
        {
          name      = "MONGO_URI"
          valueFrom = aws_secretsmanager_secret_version.mongo_uri.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/api"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_task_definition" "queued-tasks-worker" {
  family                   = "${var.environment}-queued-tasks-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "queued-tasks-worker"
      image     = "${var.api_image}:${var.image_tag}"
      essential = true

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "IS_QUEUED_TASKS_WORKER", value = "1" },
        { name = "NODE_OPTIONS", value = "--max-old-space-size=4500" },
        { name = "BASE_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_WEBHOOKS_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_OAUTH_CALLBACK_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "CUSTOM_CODE_RUNNER_URI", value = "http://custom-code-runner.${var.environment}.local:5000" },
        { name = "OPENAI_API_KEY", value = var.openai_api_key },
        { name = "ANTHROPIC_API_KEY", value = var.anthropic_api_key },
        { name = "AUTH0_DOMAIN", value = var.auth0_domain },
        { name = "AUTH0_CLIENT_ID", value = var.auth0_client_id },
        { name = "AUTH0_CLIENT_SECRET", value = var.auth0_client_secret },
        { name = "COPILOT_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "TMP_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "CONNECTORS_S3_BUCKET", value = aws_s3_bucket.connectors.id },
        { name = "STATIC_S3_BUCKET", value = aws_s3_bucket.static.id },
        { name = "BASE_STATIC_URI", value = "https://${aws_route53_record.static.name}" },
        { name = "BASE_STATIC_URI", value = "https://static.int-membrane.com" },
        { name = "REDIS_CLUSTER_URI_1", value = local.redis_configuration_endpoint },
        { name = "REDIS_DISABLE_TLS_VERIFICATION", value = "true" },
        { name = "PORT", value = "5000" },
        { name = "HOST", value = "0.0.0.0" },
        { name = "AWS_REGION", value = var.AWS_REGION },
      ]
      secrets = [
        { name = "SECRET", valueFrom = aws_ssm_parameter.secret.arn },
        { name = "ENCRYPTION_SECRET", valueFrom = aws_ssm_parameter.encryption_secret.arn },
        {
          name      = "MONGO_URI"
          valueFrom = aws_secretsmanager_secret_version.mongo_uri.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/queued-tasks-worker"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_task_definition" "instant-tasks-worker" {
  family                   = "${var.environment}-instant-tasks-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "instant-tasks-worker"
      image     = "${var.api_image}:${var.image_tag}"
      essential = true

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "IS_INSTANT_TASKS_WORKER", value = "1" },
        { name = "NODE_OPTIONS", value = "--max-old-space-size=4500" },
        { name = "BASE_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_WEBHOOKS_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_OAUTH_CALLBACK_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "CUSTOM_CODE_RUNNER_URI", value = "http://custom-code-runner.${var.environment}.local:5000" },
        { name = "OPENAI_API_KEY", value = var.openai_api_key },
        { name = "ANTHROPIC_API_KEY", value = var.anthropic_api_key },
        { name = "AUTH0_DOMAIN", value = var.auth0_domain },
        { name = "AUTH0_CLIENT_ID", value = var.auth0_client_id },
        { name = "AUTH0_CLIENT_SECRET", value = var.auth0_client_secret },
        { name = "COPILOT_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "TMP_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "CONNECTORS_S3_BUCKET", value = aws_s3_bucket.connectors.id },
        { name = "STATIC_S3_BUCKET", value = aws_s3_bucket.static.id },
        { name = "BASE_STATIC_URI", value = "https://${aws_route53_record.static.name}" },
        { name = "REDIS_CLUSTER_URI_1", value = local.redis_configuration_endpoint },
        { name = "REDIS_DISABLE_TLS_VERIFICATION", value = "true" },
        { name = "PORT", value = "5000" },
        { name = "HOST", value = "0.0.0.0" },
        { name = "AWS_REGION", value = var.AWS_REGION },
      ]
      secrets = [
        { name = "SECRET", valueFrom = aws_ssm_parameter.secret.arn },
        { name = "ENCRYPTION_SECRET", valueFrom = aws_ssm_parameter.encryption_secret.arn },
        {
          name      = "MONGO_URI"
          valueFrom = aws_secretsmanager_secret_version.mongo_uri.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/instant-tasks-worker"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_task_definition" "orchestrator" {
  family                   = "${var.environment}-orchestrator"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "orchestrator"
      image     = "${var.api_image}:${var.image_tag}"
      essential = true

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "IS_ORCHESTRATOR", value = "1" },
        { name = "NODE_OPTIONS", value = "--max-old-space-size=4500" },
        { name = "BASE_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_WEBHOOKS_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "BASE_OAUTH_CALLBACK_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "CUSTOM_CODE_RUNNER_URI", value = "http://custom-code-runner.${var.environment}.local:5000" },
        { name = "OPENAI_API_KEY", value = var.openai_api_key },
        { name = "ANTHROPIC_API_KEY", value = var.anthropic_api_key },
        { name = "AUTH0_DOMAIN", value = var.auth0_domain },
        { name = "AUTH0_CLIENT_ID", value = var.auth0_client_id },
        { name = "AUTH0_CLIENT_SECRET", value = var.auth0_client_secret },
        { name = "COPILOT_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "TMP_S3_BUCKET", value = aws_s3_bucket.tmp.id },
        { name = "CONNECTORS_S3_BUCKET", value = aws_s3_bucket.connectors.id },
        { name = "STATIC_S3_BUCKET", value = aws_s3_bucket.static.id },
        { name = "BASE_STATIC_URI", value = "https://${aws_route53_record.static.name}" },
        { name = "REDIS_CLUSTER_URI_1", value = local.redis_configuration_endpoint },
        { name = "REDIS_DISABLE_TLS_VERIFICATION", value = "true" },
        { name = "PORT", value = "5000" },
        { name = "HOST", value = "0.0.0.0" },
        { name = "AWS_REGION", value = var.AWS_REGION },
      ]
      secrets = [
        { name = "SECRET", valueFrom = aws_ssm_parameter.secret.arn },
        { name = "ENCRYPTION_SECRET", valueFrom = aws_ssm_parameter.encryption_secret.arn },
        {
          name      = "MONGO_URI"
          valueFrom = aws_secretsmanager_secret_version.mongo_uri.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/orchestrator"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_task_definition" "ui" {
  family                   = "${var.environment}-ui"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "ui"
      image = "${var.ui_image}:${var.image_tag}"
      environment = [
        { name = "NEXT_PUBLIC_ENGINE_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "PORT", value = "5000" }
      ]
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/ui"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "ui"
  }
}

resource "aws_ecs_task_definition" "console" {
  family                   = "${var.environment}-console"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "console"
      image = "${var.console_image}:${var.image_tag}"
      environment = [
        { name = "NODE_VERSION", value = "20.18.1" },
        { name = "NEXT_PUBLIC_BASE_URI", value = "https://${aws_route53_record.console.name}" },
        { name = "NEXT_PUBLIC_AUTH0_DOMAIN", value = var.auth0_domain },
        { name = "NEXT_PUBLIC_ENGINE_API_URI", value = "https://${aws_route53_record.api.name}" },
        { name = "NEXT_PUBLIC_ENGINE_UI_URI", value = "https://${aws_route53_record.ui.name}" },
        { name = "NEXT_PUBLIC_AUTH0_CLIENT_ID", value = var.auth0_client_id },
        { name = "PORT", value = "5000" }
      ]
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/console"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "console"
  }
}

resource "aws_ecs_task_definition" "custom_code_runner" {
  family                   = "${var.environment}-custom-code-runner"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "custom-code-runner"
      image = "${var.custom_code_runner_image}:${var.image_tag}"
      environment = [
        { name = "PORT", value = "5000" }
      ]
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.environment}/custom-code-runner"
          "awslogs-region"        = var.AWS_REGION
          "awslogs-stream-prefix" = "ecs"
        }
      }
      repositoryCredentials = {
        credentialsParameter = aws_secretsmanager_secret.harbor_pull.arn
      }
    }
  ])

  tags = {
    Service = "custom-code-runner"
  }
}

resource "aws_ecs_service" "api" {
  name            = "${var.environment}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [aws_lb_listener.https]
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 5000
  }

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_service" "queued-tasks-worker" {
  name            = "${var.environment}-queued-tasks-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.queued-tasks-worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  depends_on = [aws_lb_listener.https]

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_service" "instant-tasks-worker" {
  name            = "${var.environment}-instant-tasks-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.instant-tasks-worker.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  depends_on = [aws_lb_listener.https]

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_service" "orchestrator" {
  name            = "${var.environment}-orchestrator"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orchestrator.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  depends_on = [aws_lb_listener.https]

  tags = {
    Service = "api"
  }
}

resource "aws_ecs_service" "ui" {
  name            = "${var.environment}-ui"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ui.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [aws_lb_listener.https]
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.ui.arn
    container_name   = "ui"
    container_port   = 5000
  }

  tags = {
    Service = "ui"
  }
}

resource "aws_ecs_service" "console" {
  name            = "${var.environment}-console"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.console.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  depends_on = [aws_lb_listener.https]
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.console.arn
    container_name   = "console"
    container_port   = 5000
  }

  tags = {
    Service = "console"
  }
}

resource "aws_ecs_service" "custom_code_runner" {
  name            = "${var.environment}-custom-code-runner"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.custom_code_runner.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  service_registries {
    registry_arn = aws_service_discovery_service.custom_code_runner.arn
  }

  tags = {
    Service = "custom-code-runner"
  }
}

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.local"
  description = "Private DNS namespace for service discovery"
  vpc         = aws_vpc.main.id

  tags = {
    Service = "custom-code-runner"
  }
}

resource "aws_service_discovery_service" "custom_code_runner" {
  name = "custom-code-runner"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      type = "A"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Service = "custom-code-runner"
  }
}

resource "aws_lb" "public" {
  name               = "${var.environment}-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Service = "alb"
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.environment}-api-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "api"
  }
}

resource "aws_lb_target_group" "ui" {
  name        = "${var.environment}-ui-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "ui"
  }
}

resource "aws_lb_target_group" "console" {
  name        = "${var.environment}-console-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-499"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "console"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.alb.certificate_arn

  depends_on = [aws_acm_certificate_validation.alb]

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
  condition {
    host_header {
      values = [aws_route53_record.api.name]
    }
  }
}

resource "aws_lb_listener_rule" "ui" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ui.arn
  }
  condition {
    host_header {
      values = [aws_route53_record.ui.name]
    }
  }
}

resource "aws_lb_listener_rule" "console" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.console.arn
  }
  condition {
    host_header {
      values = [aws_route53_record.console.name]
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
