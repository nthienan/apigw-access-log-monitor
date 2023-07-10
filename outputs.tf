output "rest_api_gateway_url" {
  value       = aws_api_gateway_stage.prod.invoke_url
  description = "REST API Gateway URL"
}

output "http_api_gateway_url" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "HTTP API Gateway URL"
}
