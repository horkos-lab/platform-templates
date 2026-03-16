data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# GitHub Actions deploy role (OIDC)
# ---------------------------------------------------------------------------
# Trust policy design notes:
#
#   aud  — must equal "sts.amazonaws.com". This is the audience GitHub sets
#          when requesting a token for AWS via the configure-aws-credentials
#          action. Using StringEquals (not StringLike) prevents wildcard abuse.
#
#   sub  — restricts assumption to exactly the main branch of this repository.
#          Format: "repo:<owner>/<repo>:ref:refs/heads/main"
#          StringEquals prevents glob matching (e.g. "repo:org/*").
#
#   job_workflow_ref (opt-in, see variable below) — adds a third layer of
#          defence that restricts assumption to a *specific workflow file*.
#          Even if an attacker creates a new workflow on main, they cannot
#          assume this role unless that file is .github/workflows/deploy.yml.
#          Format: "<owner>/<repo>/.github/workflows/<file>@refs/heads/main"
#
# NOTE: The original oidc.tf had a subtle bug — two separate StringEquals
# keys inside the same Condition object. In JSON/HCL, duplicate object keys
# are silently last-wins, meaning the `aud` check was completely ignored and
# only `sub` was evaluated. Both claims are now merged into a single
# StringEquals map so both are enforced simultaneously.
# ---------------------------------------------------------------------------

locals {
  # Base OIDC conditions: aud + sub always enforced.
  _oidc_string_equals_base = {
    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
    "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
  }

  # When job_workflow_ref_enforcement is true, add the workflow-file claim.
  # job_workflow_ref format (GitHub OIDC 2024/2025):
  #   "<org>/<repo>/.github/workflows/<file>.yml@refs/heads/<branch>"
  # Reference: https://docs.github.com/en/actions/security-for-github-actions/
  #            security-hardening-your-deployments/about-security-hardening-with-openid-connect
  _oidc_string_equals = var.oidc_enforce_workflow_ref ? merge(
    local._oidc_string_equals_base,
    {
      "token.actions.githubusercontent.com:job_workflow_ref" = "${var.github_repo}/.github/workflows/${var.oidc_workflow_ref_file}@refs/heads/main"
    }
  ) : local._oidc_string_equals_base
}

resource "aws_iam_role" "github_deploy" {
  name = "${var.name}-github-deploy"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = local._oidc_string_equals
      }
    }]
  })
}

# ---------------------------------------------------------------------------
# Least-privilege inline policy for the deploy role
# ---------------------------------------------------------------------------
# This policy grants only the permissions Terraform needs to create/update/
# destroy the resources in this configuration. It deliberately omits:
#   - execute-api:Invoke  (CI deploys infrastructure; it never calls the API)
#   - lambda:* wildcard   (scoped to specific update/publish actions)
# ---------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_deploy" {
  name = "${var.name}-github-deploy"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # ------------------------------------------------------------------ #
        # Lambda — scoped to this function only                               #
        # ------------------------------------------------------------------ #
        {
          Sid    = "LambdaManage"
          Effect = "Allow"
          Action = [
            "lambda:CreateFunction",
            "lambda:DeleteFunction",
            "lambda:GetFunction",
            "lambda:GetFunctionConfiguration",
            "lambda:UpdateFunctionCode",
            "lambda:UpdateFunctionConfiguration",
            "lambda:AddPermission",
            "lambda:RemovePermission",
            "lambda:GetPolicy",
            "lambda:ListVersionsByFunction",
            "lambda:PublishVersion",
            "lambda:PutFunctionConcurrency",
            "lambda:DeleteFunctionConcurrency",
            "lambda:TagResource",
            "lambda:UntagResource",
            "lambda:ListTags"
          ]
          Resource = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.name}"
        },

        # ------------------------------------------------------------------ #
        # CloudWatch Logs — scoped to this function's log group               #
        # The log-group ARN without ":*" covers group-level actions.          #
        # The log-group ARN with ":*" covers stream/event-level actions that  #
        # AWS requires to be granted on the child resources.                  #
        # DescribeLogGroups is a list action that requires "*" or the group   #
        # ARN without a trailing wildcard.                                    #
        # ------------------------------------------------------------------ #
        {
          Sid    = "LogsManageGroup"
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:DeleteLogGroup",
            "logs:PutRetentionPolicy",
            "logs:DeleteRetentionPolicy",
            "logs:TagLogGroup",
            "logs:UntagLogGroup",
            "logs:ListTagsLogGroup",
            "logs:ListTagsForResource",
            "logs:AssociateKmsKey",
            "logs:DisassociateKmsKey"
          ]
          Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name}"
        },
        {
          Sid    = "LogsDescribe"
          Effect = "Allow"
          Action = ["logs:DescribeLogGroups"]
          # DescribeLogGroups filters by prefix; the broad resource is required
          # because AWS does not support resource-level conditions for this action.
          Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:*"
        },

        # ------------------------------------------------------------------ #
        # IAM — scoped to roles/policies created by this stack only          #
        # PutRolePolicy + DeleteRolePolicy are required for the inline policy #
        # on the Lambda execution role.                                       #
        # ------------------------------------------------------------------ #
        {
          Sid    = "IAMRoles"
          Effect = "Allow"
          Action = [
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:GetRole",
            "iam:UpdateRole",
            "iam:PutRolePolicy",
            "iam:GetRolePolicy",
            "iam:DeleteRolePolicy",
            "iam:ListRolePolicies",
            "iam:TagRole",
            "iam:UntagRole",
            "iam:ListRoleTags"
          ]
          Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name}-*"
        },
        {
          # AttachRolePolicy / DetachRolePolicy are split into their own statement
          # with a condition that restricts which managed policies may be attached.
          # This prevents the deploy role from attaching arbitrary managed policies
          # (e.g. AdministratorAccess) to escalate its own privileges.
          Sid    = "IAMAttachScoped"
          Effect = "Allow"
          Action = [
            "iam:AttachRolePolicy",
            "iam:DetachRolePolicy",
            "iam:ListAttachedRolePolicies"
          ]
          Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name}-*"
          Condition = {
            ArnLike = {
              "iam:PolicyARN" = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
            }
          }
        },
        {
          Sid    = "IAMPassRole"
          Effect = "Allow"
          Action = ["iam:PassRole"]
          Resource = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name}-*"
          Condition = {
            StringEquals = {
              "iam:PassedToService" = "lambda.amazonaws.com"
            }
          }
        }
      ],

      # -------------------------------------------------------------------- #
      # KMS — only added when log_group_kms_key_arn is set.                  #
      # The deploy role needs kms:DescribeKey so Terraform can read the key  #
      # ARN during plan, and kms:CreateGrant is not needed here because the  #
      # log group association is handled by CloudWatch Logs using the key     #
      # policy. logs:AssociateKmsKey above wires the group to the key.       #
      # -------------------------------------------------------------------- #
      var.log_group_kms_key_arn != "" ? [
        {
          Sid    = "KMSLogsKey"
          Effect = "Allow"
          Action = [
            "kms:DescribeKey"
          ]
          Resource = var.log_group_kms_key_arn
        }
      ] : []
    )
  })
}
