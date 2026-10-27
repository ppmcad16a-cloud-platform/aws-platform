provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ppmcad16a-cloud-platform"
      Environment = "prod"
      Stack       = "cluster"
      ManagedBy   = "Terraform"
    }
  }
}
