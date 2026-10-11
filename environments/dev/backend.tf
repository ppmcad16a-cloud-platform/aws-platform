terraform {
  backend "s3" {
    # S3 bucket created by bootstrap Terraform
    bucket = "ppmcad16a-tfstate-722867460821-ap-south-1"

    # Location of dev environment state inside S3
    key = "aws/dev/terraform.tfstate"

    # AWS Mumbai
    region = "ap-south-1"

    # Enable S3 native state locking
    use_lockfile = true

    # Encrypt Terraform state
    encrypt = true
  }
}
