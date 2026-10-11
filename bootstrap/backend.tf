terraform {
  backend "s3" {
    bucket       = "ppmcad16a-tfstate-722867460821-ap-south-1"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
