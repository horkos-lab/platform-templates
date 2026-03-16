variable "name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "${{ values.name }}"
}

variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "${{ values.awsRegion }}"
}

variable "environment" {
  description = "Deployment environment (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "architecture" {
  description = "Lambda architecture: arm64 or amd64 (mapped to x86_64 for AWS)"
  type        = string
  default     = "${{ values.architecture }}"

  validation {
    condition     = contains(["arm64", "amd64"], var.architecture)
    error_message = "architecture must be arm64 or amd64."
  }
}

variable "github_repo" {
  description = "GitHub repository in owner/repo format (used for OIDC trust policy)"
  type        = string
  default     = "${{ (values.repoUrl | parseRepoUrl).owner }}/${{ values.name }}"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$", var.github_repo))
    error_message = "github_repo must be in owner/repo format (e.g. acme-corp/my-service). Letters, digits, hyphens, dots, and underscores are allowed."
  }
}

variable "oidc_enforce_workflow_ref" {
  description = <<-EOT
    When true, the OIDC trust policy adds a job_workflow_ref condition that
    restricts role assumption to a specific GitHub Actions workflow file on
    the main branch (defence-in-depth).

    The job_workflow_ref claim format is:
      "<org>/<repo>/.github/workflows/<file>.yml@refs/heads/main"

    Enabling this means ONLY the workflow file named by oidc_workflow_ref_file
    can assume the deploy role, even if other workflows on main branch exist.
    This prevents a compromised or malicious workflow from stealing credentials.

    Default: false (opt-in — enabling it requires coordination with the CI
    workflow file name, so it is left off to avoid breaking existing setups).
  EOT
  type        = bool
  default     = false
}

variable "oidc_workflow_ref_file" {
  description = <<-EOT
    Filename of the GitHub Actions workflow that is allowed to assume the deploy
    role when oidc_enforce_workflow_ref = true. Must match the actual filename
    under .github/workflows/ in the repository (without the directory prefix).
    Example: "deploy.yml"
    Has no effect when oidc_enforce_workflow_ref = false.
  EOT
  type        = string
  default     = "deploy.yml"

  validation {
    condition     = can(regex("^[a-zA-Z0-9._-]+\\.ya?ml$", var.oidc_workflow_ref_file))
    error_message = "oidc_workflow_ref_file must be a YAML filename (e.g. deploy.yml or deploy.yaml)."
  }
}

variable "timeout" {
  description = "Lambda function timeout in seconds (1–900). Load-test your function to choose an appropriate value; set it slightly above the p99 duration."
  type        = number
  default     = 30

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "timeout must be between 1 and 900 seconds."
  }
}

variable "memory_size" {
  description = "Lambda function memory in MB (128–10240). Memory allocation also controls CPU share — use AWS Lambda Power Tuning to find the cost/performance optimum."
  type        = number
  default     = 256

  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "memory_size must be between 128 and 10240 MB."
  }
}

variable "reserved_concurrent_executions" {
  description = <<-EOT
    Maximum number of concurrent executions reserved for this function.
    -1 (default) = unreserved, shares the account concurrency pool.
     0           = throttle all invocations (useful for emergency stops).
     N > 0       = hard cap; protects downstream resources and guarantees
                   capacity independent of other functions in the account.
    Note: the account limit is 1 000 by default; reserving concurrency reduces
    the pool available to other unreserved functions.
  EOT
  type        = number
  default     = -1

  validation {
    condition     = var.reserved_concurrent_executions >= -1
    error_message = "reserved_concurrent_executions must be -1 (unreserved) or a non-negative integer."
  }
}

variable "log_level" {
  description = "Application log level passed to the function as the LOG_LEVEL environment variable"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.log_level)
    error_message = "log_level must be DEBUG, INFO, WARN, or ERROR."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days. 0 = never expire (not recommended for production)."
  type        = number
  default     = 14

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be one of the values accepted by CloudWatch Logs: 0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "log_group_kms_key_arn" {
  description = <<-EOT
    ARN of a customer-managed KMS key used to encrypt the CloudWatch log group.
    Leave empty (default) to use AWS-managed encryption at rest (no extra cost,
    no additional IAM wiring required).

    When set:
      - The KMS key policy must grant logs.<region>.amazonaws.com the actions
        kms:Encrypt, kms:Decrypt, kms:ReEncrypt*, kms:GenerateDataKey*, kms:Describe*
        scoped to this log group via kms:EncryptionContext:aws:logs:arn.
      - An inline policy is automatically attached to the Lambda execution role
        granting the same KMS actions, constrained by kms:ViaService.
    Only symmetric KMS keys are supported by CloudWatch Logs.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.log_group_kms_key_arn == "" || can(regex("^arn:aws[a-z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.log_group_kms_key_arn))
    error_message = "log_group_kms_key_arn must be empty or a valid KMS key ARN (arn:aws:kms:<region>:<account>:key/<uuid>)."
  }
}

variable "application_log_level" {
  description = <<-EOT
    Verbosity for application logs emitted by the function code when log_format = JSON.
    Valid values: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
    Has no effect when log_format is Text.
  EOT
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.application_log_level)
    error_message = "application_log_level must be one of: TRACE, DEBUG, INFO, WARN, ERROR, FATAL."
  }
}

variable "system_log_level" {
  description = <<-EOT
    Verbosity for Lambda platform (system) logs when log_format = JSON.
    Valid values: DEBUG, INFO, WARN.
    Has no effect when log_format is Text.
  EOT
  type        = string
  default     = "WARN"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN"], var.system_log_level)
    error_message = "system_log_level must be one of: DEBUG, INFO, WARN."
  }
}

# ---------------------------------------------------------------------------
# Cross-variable validation using check blocks
#
# Terraform variable validation blocks can only reference the variable being
# validated — cross-variable conditions (e.g. "if production, then X") require
# a check block (introduced in Terraform 1.5).
#
# IMPORTANT: check block assertions produce WARNINGS, not hard errors. A
# failed check does not abort plan/apply; it surfaces a visible warning so
# operators can catch misconfiguration before it reaches production. If a hard
# error is required, enforce the constraint in CI (e.g. Open Policy Agent /
# Conftest) in addition to these checks.
# ---------------------------------------------------------------------------

check "production_log_retention" {
  assert {
    # Production environments must retain logs for at least 30 days to meet
    # common compliance baselines (SOC 2, PCI-DSS, ISO 27001).
    # log_retention_days = 0 means "never expire" and is therefore also valid.
    condition = var.environment != "production" || var.log_retention_days == 0 || var.log_retention_days >= 30
    error_message = "Production environment: log_retention_days must be 0 (never expire) or >= 30. Current value: ${var.log_retention_days}."
  }
}

check "production_reserved_concurrency" {
  assert {
    # Production environments should have an explicit concurrency cap to protect
    # downstream resources and guarantee capacity. Using -1 (unreserved) in
    # production means a traffic spike in another function can exhaust the entire
    # account concurrency pool and throttle this function without warning.
    condition     = var.environment != "production" || var.reserved_concurrent_executions != -1
    error_message = "Production environment: reserved_concurrent_executions must not be -1 (unreserved). Set an explicit cap (>= 0) appropriate for your traffic profile."
  }
}
