locals {
  vector_api_port        = 8686
  vector_prometheus_port = 18687
}

##########################################
# ECS Service
##########################################
resource "aws_ecs_service" "vector" {
  name = "vector"

  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.vector.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.vector.arn
    container_name   = "vector"
    container_port   = local.vector_prometheus_port
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [module.vector_sg.security_group_id]
  }
}

module "vector_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "vector-ecs-sg"
  description = "Security group for vector ECS tasks"

  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = local.vector_prometheus_port
      to_port     = local.vector_prometheus_port
      protocol    = "tcp"
      cidr_blocks = data.aws_vpc.selected.cidr_block
      description = "Allow VPC access"
    }
  ]

  egress_rules = ["all-all"]
}
##########################################
# ECS Task Definition
##########################################

resource "aws_ecs_task_definition" "vector" {
  family = "vector"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  task_role_arn      = aws_iam_role.vector_ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_task_role.arn

  volume {
    name = "config"
  }

  container_definitions = jsonencode([
    {
      name  = "config-init"
      image = "ubuntu:23.10"
      entryPoint = [
        "bash",
        "-c",
        "set -ueo pipefail; mkdir -p /etc/vector/; echo ${base64encode(
          templatefile("${path.module}/templates/vector-config.yaml.tpl", {
            region        = data.aws_region.current.name
            sqs_queue_url = aws_sqs_queue.apigw_access_log.url

            api_port        = local.vector_api_port
            prometheus_port = local.vector_prometheus_port
          })
        )} | base64 -d > /etc/vector/vector.yaml; cat /etc/vector/vector.yaml",
      ]

      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/etc/vector"
      }]

      essential              = false
      readonlyRootFilesystem = false
      privileged             = false
      stopTimeout            = 10

      logConfiguration = {
        logDriver     = "awslogs"
        secretOptions = null
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "vector"
        }
      }
    },

    {
      name  = "vector"
      image = "timberio/vector:0.30.0-distroless-libc"
      command = [
        "--config-dir",
        "/etc/vector/"
      ]

      essential              = true
      readonlyRootFilesystem = false
      privileged             = false

      portMappings = [{
        containerPort = local.vector_api_port
        }, {
        containerPort = local.vector_prometheus_port
      }]

      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/etc/vector"
      }]

      dependsOn = [{
        containerName = "config-init"
        condition     = "SUCCESS"
      }]

      logConfiguration = {
        logDriver     = "awslogs"
        secretOptions = null
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "vector"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}

##########################################
# ECS Task Roles
##########################################
resource "aws_iam_role" "vector_ecs_task_role" {
  name        = "vector-ecs-task-role"
  description = "The ECS task role for vector"

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

resource "aws_iam_role_policy_attachment" "vector_ecs_task_role_policy" {
  role       = aws_iam_role.vector_ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "vector_sqs" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage"
    ]

    resources = [
      aws_sqs_queue.apigw_access_log.arn
    ]
  }
}

resource "aws_iam_role_policy" "vector_sqs" {
  name   = "sqs"
  role   = aws_iam_role.vector_ecs_task_role.id
  policy = data.aws_iam_policy_document.vector_sqs.json
}
