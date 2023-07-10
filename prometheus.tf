##########################################
# ECS Service
##########################################
resource "aws_ecs_service" "prometheus" {
  name = "prometheus"

  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [module.prometheus_sg.security_group_id]
  }
}

module "prometheus_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "prometheus-ecs-sg"
  description = "Security group for prometheus ECS tasks"

  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [{
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = data.aws_vpc.selected.cidr_block
    description = "Allow VPC access"
  }]
  egress_rules = ["all-all"]
}

##########################################
# ECS Task Definition
##########################################

resource "aws_ecs_task_definition" "prometheus" {
  family = "prometheus"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "512"
  memory = "2048"

  task_role_arn      = aws_iam_role.ecs_task_role.arn
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
        "set -ueo pipefail; mkdir -p /etc/prometheus/; echo ${base64encode(
          templatefile("${path.module}/templates/prometheus-config.yml.tpl", {
            vector_alb_dns_name    = aws_lb.internal_nlb.dns_name
            vector_prometheus_port = local.vector_prometheus_port
          })
        )} | base64 -d > /etc/prometheus/prometheus.yml; cat /etc/prometheus/prometheus.yml",
      ]

      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/etc/prometheus"
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
          awslogs-stream-prefix = "prometheus"
        }
      }
    },

    {
      name  = "prometheus"
      image = "prom/prometheus:v2.45.0"
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus"
      ]

      essential              = true
      readonlyRootFilesystem = false
      privileged             = false

      portMappings = [{
        containerPort = 9090
      }]

      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/etc/prometheus"
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
          awslogs-stream-prefix = "prometheus"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}
