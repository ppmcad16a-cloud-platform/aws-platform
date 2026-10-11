output "state_bucket_name" {
  description = "S3 bucket storing Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.terraform_state.arn
}

output "plan_role_arn" {
  value = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}
