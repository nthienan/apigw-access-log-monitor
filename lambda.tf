module "apigw_access_log_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "5.0.0"

  function_name = local.common_name
  description   = "The function sends API Gateway access log to SQS queue"

  source_path = [{
    path             = "assets/lambda/apigw-access-log/index.py"
    pip_requirements = false
  }]

  environment_variables = {
    SQS_QUEUE_URL    = aws_sqs_queue.apigw_access_log.url
    SQS_QUEUE_REGION = data.aws_region.current.name
  }

  handler       = "index.lambda_handler"
  runtime       = "python3.10"
  timeout       = 60
  memory_size   = 128
  architectures = ["x86_64"]

  attach_policy_statements = true
  policy_statements = {
    sqs = {
      effect    = "Allow",
      actions   = ["sqs:SendMessage", "sqs:GetQueueUrl"],
      resources = [aws_sqs_queue.apigw_access_log.arn]
    }
  }

  cloudwatch_logs_retention_in_days = 1
}

resource "aws_lambda_permission" "cloudwatch_logs" {
  action        = "lambda:InvokeFunction"
  function_name = module.apigw_access_log_function.lambda_function_name
  principal     = "logs.${data.aws_region.current.name}.amazonaws.com"
  source_arn    = format("%s:*", aws_cloudwatch_log_group.apigw_access_log.arn)
}
