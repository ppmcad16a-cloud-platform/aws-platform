# GKE's outgoing IP (Jenkins runs there). Read from GCP's state; empty if the
# GKE cluster isn't running yet -> start GCP first, or re-apply afterwards.
data "terraform_remote_state" "gcp_cluster" {
  backend = "gcs"
  config = {
    bucket = "project-899ced78-a554-40c2-96c-tfstate"
    prefix = "prod/cluster"
  }
}

locals {
  gke_egress_cidrs = [for ip in compact([try(data.terraform_remote_state.gcp_cluster.outputs.egress_ip, "")]) : "${ip}/32"]
}

# Who is running Terraform right now? With SSO this is a temporary session;
# "issuer_arn" is the underlying IAM ROLE - that is what gets cluster-admin.
data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

module "network" {
  source = "../../../modules/network"
  name   = "prod"
  cidr   = "10.10.0.0/16"
}

module "eks" {
  source = "../../../modules/eks"

  name                 = "prod-eks"
  subnet_ids           = module.network.private_subnet_ids
  admin_cidrs          = concat([var.admin_cidr], local.gke_egress_cidrs)
  admin_principal_arns = [data.aws_iam_session_context.current.issuer_arn]
  instance_type        = var.instance_type
  capacity_type        = var.capacity_type
}

# Fixed public IP for the web entrance (Cloudflare's origin for AWS).
resource "aws_eip" "ingress" {
  domain = "vpc"
  tags = {
    Name = "eip-prod-ingress"
  }
}
