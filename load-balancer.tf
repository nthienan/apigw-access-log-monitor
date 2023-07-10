locals {
  mirror_http_server_name = "mirror-http-server"
}

##########################################
# ALB
##########################################

resource "aws_lb" "external" {
  name               = "${local.common_name}-ext-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [module.alb_sg.security_group_id]
}

## grafana
resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.external.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_lb_target_group" "grafana" {
  name        = "grafana-tg"
  target_type = "ip"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    path = "/api/health"
  }
}

##########################################
# NLB
##########################################
resource "aws_lb" "internal_nlb" {
  name               = "${local.common_name}-int-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
}

## mirror-http-server
resource "aws_lb_listener" "mirror_http_server" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mirror_http_server.arn
  }
}

resource "aws_lb_target_group" "mirror_http_server" {
  name        = "${local.mirror_http_server_name}-tg"
  target_type = "ip"
  port        = 8080
  protocol    = "TCP"
  vpc_id      = var.vpc_id
}

## vector
resource "aws_lb_listener" "vector" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = local.vector_prometheus_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vector.arn
  }
}

resource "aws_lb_target_group" "vector" {
  name        = "vector-tg"
  target_type = "ip"
  port        = 18687
  protocol    = "TCP"
  vpc_id      = var.vpc_id
}

## prometheus
resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.internal_nlb.arn
  port              = 9090
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}

resource "aws_lb_target_group" "prometheus" {
  name        = "prometheus-tg"
  target_type = "ip"
  port        = 9090
  protocol    = "TCP"
  vpc_id      = var.vpc_id
}

##########################################
# Security group
##########################################
module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "${local.common_name}-ext-alb-sg"
  description = "Security group for external ALB"

  vpc_id = var.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]

  egress_rules = ["all-all"]
}
