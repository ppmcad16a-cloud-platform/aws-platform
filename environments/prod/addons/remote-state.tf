data "terraform_remote_state" "cluster" {
  backend = "s3"
  config = {
    bucket = "ppmcad16a-tfstate-722867460821-ap-south-1"
    key    = "aws/prod/cluster/terraform.tfstate"
    region = "ap-south-1"
  }
}

data "aws_caller_identity" "current" {}
