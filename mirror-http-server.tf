##########################################
# ECS Service
##########################################
resource "aws_ecs_service" "mirror_http_server" {
  name = "mirror-http-server"

  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.mirror_http_server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.mirror_http_server.arn
    container_name   = "mirror-http-server"
    container_port   = 8080
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [module.mirror_http_server_sg.security_group_id]
  }
}

module "mirror_http_server_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "mirror-http-server-ecs-sg"
  description = "Security group for mirror-http-server ECS tasks"

  vpc_id = var.vpc_id

  ingress_with_cidr_blocks = [{
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = data.aws_vpc.selected.cidr_block
    description = "Allow VPC access"
  }]
  egress_rules = ["all-all"]
}

##########################################
# ECS Task Definition
##########################################
resource "aws_ecs_task_definition" "mirror_http_server" {
  family = "mirror-http-server"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = "256"
  memory = "512"

  task_role_arn      = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name  = "mirror-http-server"
    image = "eexit/mirror-http-server:v2.1.2"

    essential = true

    portMappings = [{
      containerPort = 8080
    }]

    # logConfiguration = {
    #   logDriver     = "awslogs"
    #   secretOptions = null
    #   options = {
    #     awslogs-group         = aws_cloudwatch_log_group.ecs_log.name
    #     awslogs-region        = data.aws_region.current.name
    #     awslogs-stream-prefix = "mirror-http-server"
    #   }
    # }

  }])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
}
