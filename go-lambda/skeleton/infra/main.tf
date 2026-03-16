provider "aws" {
  region = var.aws_region
}

locals {
  # AWS uses "x86_64" where Go / Docker toolchains use "amd64"
  lambda_arch = var.architecture == "amd64" ? "x86_64" : var.architecture

  tags = {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# CloudWatch Logs
# ---------------------------------------------------------------------------

# Create the log group explicitly so we can control retention and tagging.
# Must exist before the Lambda function; enforced via depends_on in the
# aws_lambda_function resource and via the logging_config block pointing at it.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days

  # Optional KMS encryption. When log_group_kms_key_arn is set:
  #   1. The KMS key policy must grant the CloudWatch Logs service principal
  #      (logs.<region>.amazonaws.com) kms:Encrypt, kms:Decrypt, kms:ReEncrypt*,
  #      kms:GenerateDataKey*, and kms:Describe* — scoped via:
  #        "kms:EncryptionContext:aws:logs:arn": "<log-group-arn>"
  #   2. The Lambda execution role also needs those same actions on the key
  #      (see the conditional inline policy below) so it can write log events.
  # Leave empty (default) to use the AWS-managed log encryption at rest.
  kms_key_id = var.log_group_kms_key_arn != "" ? var.log_group_kms_key_arn : null

  tags = local.tags
}

# ---------------------------------------------------------------------------
# IAM — Lambda execution role
# ---------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name = "${var.name}-lambda"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# AWSLambdaBasicExecutionRole grants logs:CreateLogGroup, logs:CreateLogStream,
# and logs:PutLogEvents — the minimum needed to write to CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# When the log group is KMS-encrypted, the Lambda execution role must be able
# to call kms:GenerateDataKey* (to encrypt log events it writes) and kms:Decrypt
# (to read them back). The kms:ViaService condition scopes these permissions to
# CloudWatch Logs only, so the role cannot use the key for anything else.
resource "aws_iam_role_policy" "lambda_kms_logs" {
  count = var.log_group_kms_key_arn != "" ? 1 : 0

  name = "${var.name}-lambda-kms-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowCWLogsKMS"
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Describe*"
      ]
      Resource = var.log_group_kms_key_arn
      Condition = {
        StringEquals = {
          "kms:ViaService" = "logs.${var.aws_region}.amazonaws.com"
        }
      }
    }]
  })
}

# ---------------------------------------------------------------------------
# Lambda function
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "this" {
  function_name = var.name
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = [local.lambda_arch]

  # The zip is built by the CI pipeline (just build && just package) and placed
  # at dist/function.zip relative to the repository root before Terraform runs.
  filename         = "${path.module}/../dist/function.zip"
  source_code_hash = filebase64sha256("${path.module}/../dist/function.zip")

  role        = aws_iam_role.lambda.arn
  timeout     = var.timeout
  memory_size = var.memory_size

  # -1 means "unreserved" (shares the account pool).
  # Set to a positive value to cap concurrency and protect downstream resources.
  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = {
      LOG_LEVEL   = var.log_level
      ENVIRONMENT = var.environment
    }
  }

  # Advanced logging controls (requires AWS provider >= 5.60).
  # log_format = "JSON" enables structured logging and activates
  # application_log_level / system_log_level filtering.
  # log_group links the function to the explicitly managed log group above,
  # which gives Terraform full control over retention and prevents Lambda from
  # auto-creating an unmanaged group on first invocation.
  logging_config {
    log_format            = "JSON"
    log_group             = aws_cloudwatch_log_group.lambda.name
    application_log_level = var.application_log_level
    system_log_level      = var.system_log_level
  }

  # Ensure the log group is created before the function so that the
  # logging_config reference is always valid at deploy time.
  depends_on = [aws_cloudwatch_log_group.lambda]

  # -------------------------------------------------------------------------
  # lifecycle — create_before_destroy is intentionally NOT set here.
  #
  # AWS Lambda function names must be unique within a region. Terraform's
  # create_before_destroy replaces a resource by creating the new object
  # *before* destroying the old one — which means both would exist at the same
  # time under the same name, causing the CreateFunction API call to fail with
  # ResourceConflictException.
  #
  # Workarounds exist (name_prefix + random suffix), but they change the
  # function ARN on every replacement, break API Gateway integrations, and
  # complicate blue/green traffic shifting. The default destroy-then-create
  # order is correct for named Lambda functions.
  #
  # Reference: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
  # -------------------------------------------------------------------------

  tags = local.tags
}
