resource "aws_sqs_queue" "apigw_access_log" {
  name = local.common_name

  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600 # 14 days
}
