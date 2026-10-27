terraform {
  backend "s3" {
    bucket       = "ppmcad16a-tfstate-722867460821-ap-south-1"
    key          = "aws/prod/foundation/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
    encrypt      = true
  }
}
