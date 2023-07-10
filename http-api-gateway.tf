##########################################
# HTTP API Gateway
##########################################
resource "aws_apigatewayv2_api" "http_apigw" {
  name          = "${local.common_name}-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "root_proxy" {
  api_id    = aws_apigatewayv2_api.http_apigw.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.private_alb_integration.id}"
}

resource "aws_apigatewayv2_integration" "private_alb_integration" {
  api_id      = aws_apigatewayv2_api.http_apigw.id
  description = "NLB mirror-http-server integration"

  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.mirror_http_server.arn

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.http_apigw_vpc_link.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_apigw.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_access_log.arn
    format = jsonencode({
      "time"               = "$context.requestTimeEpoch"
      "path"               = "$context.path"
      "method"             = "$context.httpMethod"
      "status"             = "$context.status"
      "latency"            = "$context.responseLatency"
      "integrationLatency" = "$context.integration.latency"
      "responseLength"     = "$context.responseLength"
      "ip"                 = "$context.identity.sourceIp"
      "userAgent"          = "$context.identity.userAgent"
      "routeKey"           = "$context.routeKey"
      "protocol"           = "$context.protocol"
      "stage"              = "$context.stage"
      "requestId"          = "$context.requestId"
      "gatewayId"          = "$context.apiId"
      "apiKeyId"           = "-"
      "principalId"        = "$context.authorizer.principalId"
    })
  }
}

##########################################
# Cloudwatch Logs
##########################################
resource "aws_cloudwatch_log_group" "apigw_access_log" {
  name = "/aws/apigateway/${local.common_name}"

  retention_in_days = 30
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_cloudwatch_log_subscription_filter" "eu_apigw_access_log" {
  name = "cwl-2-sqs"

  log_group_name  = aws_cloudwatch_log_group.apigw_access_log.name
  destination_arn = module.apigw_access_log_function.lambda_function_arn
  filter_pattern  = ""
}

##########################################
# VPC Link
##########################################
resource "aws_apigatewayv2_vpc_link" "http_apigw_vpc_link" {
  name               = "${local.common_name}-http-api"
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [module.vpc_link_sg.security_group_id]
}

module "vpc_link_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "${local.common_name}-vpc-link"
  description = "Security group for API Gateway VPC Link"

  vpc_id = var.vpc_id

  ingress_cidr_blocks = [data.aws_vpc.selected.cidr_block]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]
}

#######################################
# IAM Roles & Policies
#######################################
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudwatch" {
  name               = "${local.common_name}-apigw-cloudwatch"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]

    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/apigateway/*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/apigateway/*:*"
    ]
  }
}

resource "aws_iam_role_policy" "cloudwatch" {
  name   = "default"
  role   = aws_iam_role.cloudwatch.id
  policy = data.aws_iam_policy_document.cloudwatch.json
}
