# ============================================================
# AWS Region
#
# Specifies where Terraform creates AWS resources.
# We are using Mumbai (ap-south-1).
# ============================================================

variable "aws_region" {
  description = "AWS region for Terraform infrastructure"
  type        = string
  default     = "ap-south-1"
}


# ============================================================
# Terraform State Bucket Name
#
# S3 bucket names must be globally unique.
# We'll provide the actual name during terraform plan.
# ============================================================

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state"
  type        = string
}