resource "aws_iam_role" "ecs_execution" {
  name = "${var.environment}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Service = "core"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Service = "core"
  }
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "${var.environment}-ecs-task-policy"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_s3_bucket.connectors.arn,
          "${aws_s3_bucket.connectors.arn}/*",
          aws_s3_bucket.static.arn,
          "${aws_s3_bucket.static.arn}/*",
          aws_s3_bucket.tmp.arn,
          "${aws_s3_bucket.tmp.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_execution_harbor_pull" {
  name        = "${var.environment}-ecs-execution-harbor-pull"
  description = "Allow ECS execution role to pull Harbor credentials from Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = aws_secretsmanager_secret.harbor_pull.arn
      }
    ]
  })

  tags = {
    Service = "core"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_harbor_pull" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_execution_harbor_pull.arn
}

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "ecs_execution_ssm_parameters" {
  name        = "${var.environment}-ecs-execution-ssm-parameters"
  description = "Allow ECS execution role to read SSM parameters for secrets"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath"
        ],
        Resource = [
          "arn:aws:ssm:${var.AWS_REGION}:${data.aws_caller_identity.current.account_id}:parameter/${var.environment}/integration-app/*"
        ]
      }
    ]
  })

  tags = {
    Service = "core"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution_ssm_parameters" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.ecs_execution_ssm_parameters.arn
}

resource "aws_iam_role_policy" "ecs_execution_docdb_secret" {
  name = "${var.environment}-ecs-execution-docdb-secret"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "*"
      }
    ]
  })
}
