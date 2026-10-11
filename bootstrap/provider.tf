provider "aws" {
  # AWS Mumbai region.
  region = var.aws_region

  # AWS IAM Identity Center profile.
  profile = "platform-admin-shuaib"

  default_tags {
    tags = {
      Project     = "ppmcad16a-cloud-platform"
      Environment = "shared"
      ManagedBy   = "Terraform"
    }
  }
}