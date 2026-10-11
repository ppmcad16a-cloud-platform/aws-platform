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
  default     = "ppmcad16a-tfstate-722867460821-ap-south-1"
}

variable "github_org" {
  type    = string
  default = "ppmcad16a-cloud-platform"
}

variable "github_repo" {
  description = "Repository whose GitHub Actions may use the roles"
  type        = string
  default     = "aws-platform"
}

variable "budget_usd" {
  type    = number
  default = 10
}

variable "alert_email" {
  type    = string
  default = "rishav1994sonai@gmail.com"
}
