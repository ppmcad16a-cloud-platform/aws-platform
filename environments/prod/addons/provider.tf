provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ppmcad16a-cloud-platform"
      Environment = "prod"
      Stack       = "addons"
      ManagedBy   = "Terraform"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Helm logs in exactly like kubectl: "aws eks get-token" with your AWS_PROFILE.
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.aws_region]
    }
  }
}
