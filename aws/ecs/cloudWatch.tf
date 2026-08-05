resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.environment}/api"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "ui" {
  name              = "/ecs/${var.environment}/ui"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "console" {
  name              = "/ecs/${var.environment}/console"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "custom_code_runner" {
  name              = "/ecs/${var.environment}/custom-code-runner"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "worker" {
  for_each = local.worker_roles

  name              = "/ecs/${var.environment}/${each.key}"
  retention_in_days = 30
}
