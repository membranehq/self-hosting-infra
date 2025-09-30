resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.environment}/api"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "ui" {
  name              = "/ecs/${var.environment}/ui"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "console" {
  name              = "/ecs/${var.environment}/console"
  retention_in_days = 1
}

resource "aws_cloudwatch_log_group" "custom_code_runner" {
  name              = "/ecs/${var.environment}/custom-code-runner"
  retention_in_days = 1
}
resource "aws_cloudwatch_log_group" "queued-tasks-worker" {
  name              = "/ecs/${var.environment}/queued-tasks-worker"
  retention_in_days = 1
}
resource "aws_cloudwatch_log_group" "instant-tasks-worker" {
  name              = "/ecs/${var.environment}/instant-tasks-worker"
  retention_in_days = 1
}
resource "aws_cloudwatch_log_group" "orchestrator" {
  name              = "/ecs/${var.environment}/orchestrator"
  retention_in_days = 1
}
