provider "aws" {
  region  = "ap-south-1"

  default_tags {
    tags = {
      Project     = "ppmcad16a-cloud-platform"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}