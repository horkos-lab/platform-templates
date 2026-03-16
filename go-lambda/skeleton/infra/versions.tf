terraform {
  # Minimum 1.10 for:
  #   - S3 native state locking (use_lockfile=true, Terraform 1.10+)
  #   - input variable validation with references (Terraform 1.9)
  #   - general stability improvements over 1.5
  required_version = "~> 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # ~> 5.60 for Lambda logging_config block (introduced in 5.60)
      # Upper bound < 6.0 prevents accidental major-version upgrades
      version = "~> 5.60"
    }
  }

  # Partial S3 backend configuration — credentials and bucket details are
  # supplied at init time so they are never committed to source control.
  #
  # First-time init (from local machine or bootstrap CI job):
  #
  #   terraform init \
  #     -backend-config="bucket=<tfstate-bucket>" \
  #     -backend-config="key=<service-name>/terraform.tfstate" \
  #     -backend-config="region=<aws-region>" \
  #     -backend-config="encrypt=true" \
  #     -backend-config="use_lockfile=true"
  #
  # use_lockfile=true uses S3-native locking (no DynamoDB table required).
  # DynamoDB-based locking is deprecated since Terraform 1.10 and will be
  # removed in a future version.
  backend "s3" {}
}
