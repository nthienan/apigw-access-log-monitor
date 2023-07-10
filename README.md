# Amazon API Gateway Monitor

This repository contains Terraform code to provision a demo environment for the article **[Transforming Amazon API Gateway Access Log Into Prometheus Metrics](https://community.aws/posts/transforming-amazon-api-gateway-access-log-into-prometheus-metrics)**


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.5.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb_sg"></a> [alb\_sg](#module\_alb\_sg) | terraform-aws-modules/security-group/aws | 5.1.0 |
| <a name="module_apigw_access_log_function"></a> [apigw\_access\_log\_function](#module\_apigw\_access\_log\_function) | terraform-aws-modules/lambda/aws | 5.0.0 |
| <a name="module_grafana_sg"></a> [grafana\_sg](#module\_grafana\_sg) | terraform-aws-modules/security-group/aws | 5.1.0 |
| <a name="module_mirror_http_server_sg"></a> [mirror\_http\_server\_sg](#module\_mirror\_http\_server\_sg) | terraform-aws-modules/security-group/aws | 5.1.0 |
| <a name="module_prometheus_sg"></a> [prometheus\_sg](#module\_prometheus\_sg) | terraform-aws-modules/security-group/aws | 5.1.0 |
| <a name="module_vector_sg"></a> [vector\_sg](#module\_vector\_sg) | terraform-aws-modules/security-group/aws | 5.1.0 |
| <a name="module_vpc_link_sg"></a> [vpc\_link\_sg](#module\_vpc\_link\_sg) | terraform-aws-modules/security-group/aws | 5.1.0 |

## Resources

| Name | Type |
|------|------|
| aws_api_gateway_account.this | resource |
| aws_api_gateway_deployment.prod | resource |
| aws_api_gateway_integration.this | resource |
| aws_api_gateway_method.any | resource |
| aws_api_gateway_resource.proxy | resource |
| aws_api_gateway_rest_api.rest_apigw | resource |
| aws_api_gateway_stage.prod | resource |
| aws_api_gateway_vpc_link.rest_apigw_vpc_link | resource |
| aws_apigatewayv2_api.http_apigw | resource |
| aws_apigatewayv2_integration.private_alb_integration | resource |
| aws_apigatewayv2_route.root_proxy | resource |
| aws_apigatewayv2_stage.default | resource |
| aws_apigatewayv2_vpc_link.http_apigw_vpc_link | resource |
| aws_cloudwatch_log_group.apigw_access_log | resource |
| aws_cloudwatch_log_group.ecs_log | resource |
| aws_cloudwatch_log_subscription_filter.eu_apigw_access_log | resource |
| aws_ecs_cluster.this | resource |
| aws_ecs_service.grafana | resource |
| aws_ecs_service.mirror_http_server | resource |
| aws_ecs_service.prometheus | resource |
| aws_ecs_service.vector | resource |
| aws_ecs_task_definition.grafana | resource |
| aws_ecs_task_definition.mirror_http_server | resource |
| aws_ecs_task_definition.prometheus | resource |
| aws_ecs_task_definition.vector | resource |
| aws_iam_role.cloudwatch | resource |
| aws_iam_role.ecs_task_role | resource |
| aws_iam_role.vector_ecs_task_role | resource |
| aws_iam_role_policy.cloudwatch | resource |
| aws_iam_role_policy.vector_sqs | resource |
| aws_iam_role_policy_attachment.ecs_task_role_policy | resource |
| aws_iam_role_policy_attachment.vector_ecs_task_role_policy | resource |
| aws_lambda_permission.cloudwatch_logs | resource |
| aws_lb.external | resource |
| aws_lb.internal_nlb | resource |
| aws_lb_listener.grafana | resource |
| aws_lb_listener.mirror_http_server | resource |
| aws_lb_listener.prometheus | resource |
| aws_lb_listener.vector | resource |
| aws_lb_target_group.grafana | resource |
| aws_lb_target_group.mirror_http_server | resource |
| aws_lb_target_group.prometheus | resource |
| aws_lb_target_group.vector | resource |
| aws_sqs_queue.apigw_access_log | resource |
| aws_caller_identity.current | data source |
| aws_iam_policy_document.assume_role | data source |
| aws_iam_policy_document.cloudwatch | data source |
| aws_iam_policy_document.vector_sqs | data source |
| aws_region.current | data source |
| aws_vpc.selected | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | The AWS region where resources created | `string` | `"us-east-1"` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Subnet IDs where resources created | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Subnet IDs where resources created | `list(string)` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_http_api_gateway_url"></a> [http\_api\_gateway\_url](#output\_http\_api\_gateway\_url) | HTTP API Gateway URL |
| <a name="output_rest_api_gateway_url"></a> [rest\_api\_gateway\_url](#output\_rest\_api\_gateway\_url) | REST API Gateway URL |
<!-- END_TF_DOCS -->
