locals {
  gke_issuer_host = trimprefix(var.gke_issuer, "https://")
}

# "AWS, trust identity tokens signed by the prod-gke cluster."
resource "aws_iam_openid_connect_provider" "gke" {
  url            = var.gke_issuer
  client_id_list = ["sts.amazonaws.com"]
}

# ... but only for ONE Kubernetes service account: jenkins/jenkins-deployer.
data "aws_iam_policy_document" "jenkins_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.gke.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.gke_issuer_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.gke_issuer_host}:sub"
      values   = ["system:serviceaccount:jenkins:jenkins-deployer"]
    }
  }
}

resource "aws_iam_role" "jenkins_deployer" {
  name                 = "jenkins-deployer-from-gke"
  assume_role_policy   = data.aws_iam_policy_document.jenkins_trust.json
  max_session_duration = 3600
}

# AWS permission: ONLY "describe the prod-eks cluster" (endpoint + CA).
# What it may do INSIDE the cluster is decided by Kubernetes RBAC (mern only).
data "aws_iam_policy_document" "jenkins_deployer" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/prod-eks"]
  }
  # ... and read the node group's size: 0 nodes = a sleeping standby, which
  # the pipeline skips instead of failing (stopped-standby failover).
  statement {
    actions   = ["eks:DescribeNodegroup"]
    resources = ["arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/prod-eks/default/*"]
  }
}

resource "aws_iam_role_policy" "jenkins_deployer" {
  name   = "describe-prod-eks"
  role   = aws_iam_role.jenkins_deployer.id
  policy = data.aws_iam_policy_document.jenkins_deployer.json
}

output "jenkins_deployer_role_arn" {
  value = aws_iam_role.jenkins_deployer.arn
}
