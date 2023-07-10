##########################################
# ECS Service
##########################################
resource "aws_ecs_service" "grafana" {
  name = "grafana"

  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [module.grafana_sg.security_group_id]
  }
}

module "grafana_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "grafana-ecs-sg"
  description = "Security group for grafana ECS tasks"

  vpc_id = var.vpc_id

  ingress_with_source_security_group_id = [{
    from_port                = 3000
    to_port                  = 3000
    protocol                 = "tcp"
    source_security_group_id = module.alb_sg.security_group_id
    description              = "ALB healthcheck"
  }]
  egress_rules = ["all-all"]
}

##########################################
# ECS Task Definition
##########################################

resource "aws_ecs_task_definition" "grafana" {
  family = "grafana"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

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
        "set -ueo pipefail; mkdir -p /etc/grafana/provisioning/datasources/; echo ${base64encode(
          templatefile("${path.module}/templates/grafana-datasource.yml.tpl", {
            promethues_url = "http://${aws_lb.internal_nlb.dns_name}:9090"
          })
        )} | base64 -d > /etc/grafana/provisioning/datasources/datasource.yml",
      ]

      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/etc/grafana/provisioning"
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
          awslogs-stream-prefix = "grafana"
        }
      }
    },

    {
      name  = "grafana"
      image = "grafana/grafana:9.5.5"

      essential              = true
      readonlyRootFilesystem = false
      privileged             = false

      environment = [{
        name  = "GF_SECURITY_ADMIN_PASSWORD"
        value = "123grafana"
      }]

      portMappings = [{
        containerPort = 3000
      }]

      mountPoints = [{
        sourceVolume  = "config"
        containerPath = "/etc/grafana/provisioning"
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
          awslogs-stream-prefix = "grafana"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}
