resource "aws_api_gateway_rest_api" "rest_apigw" {
  name = "${local.common_name}-rest-api"

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_vpc_link" "rest_apigw_vpc_link" {
  name        = "${local.common_name}-rest-api"
  target_arns = [aws_lb.internal_nlb.arn]
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "any" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.any.http_method

  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.internal_nlb.dns_name}/{proxy}"
  integration_http_method = "ANY"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.rest_apigw_vpc_link.id
}

resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id

  depends_on = [
    aws_api_gateway_integration.this
  ]
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  deployment_id = aws_api_gateway_deployment.prod.id

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
      "apiKeyId"          = "$context.identity.apiKeyId"
      "principalId"        = "$context.authorizer.principalId"
    })
  }
}
