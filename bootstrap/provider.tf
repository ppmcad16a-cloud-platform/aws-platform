provider "aws" {
  # AWS Mumbai region.
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ppmcad16a-cloud-platform"
      Environment = "shared"
      ManagedBy   = "Terraform"
    }
  }
}