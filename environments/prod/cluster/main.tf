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
  admin_cidrs          = [var.admin_cidr]
  admin_principal_arns = [data.aws_iam_session_context.current.issuer_arn]
  instance_type        = var.instance_type
  capacity_type        = var.capacity_type
}
