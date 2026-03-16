output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "log_group_name" {
  description = "CloudWatch Logs log group name for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda.name
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda.arn
}

output "github_deploy_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC deploys"
  value       = aws_iam_role.github_deploy.arn
}
