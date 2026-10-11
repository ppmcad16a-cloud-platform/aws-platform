# Read the AWS account currently used by Terraform.
data "aws_caller_identity" "current" {}

# Display the account ID after Terraform apply.
output "aws_account_id" {
  description = "AWS account used for development"
  value       = data.aws_caller_identity.current.account_id
}