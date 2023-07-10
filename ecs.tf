##########################################
# ECS Cluster
##########################################
resource "aws_ecs_cluster" "this" {
  name = local.common_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "ecs_log" {
  name = "/aws/ecs/${local.common_name}"

  retention_in_days = 30
}

##########################################
# ECS Task Roles
##########################################
resource "aws_iam_role" "ecs_task_role" {
  name        = "${local.common_name}-ecs-task-role"
  description = "The shared ECS task role"

  assume_role_policy = jsonencode({
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
