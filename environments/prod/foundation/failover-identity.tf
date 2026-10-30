# ---------------------------------------------------------------
# Stopped-standby failover: the role GitHub Actions (platform-automation,
# workflow failover-wake) uses to WAKE the sleeping EKS standby when GCP
# fails - read + resize the "default" node group of prod-eks, nothing else.
# Keyless: trusts only platform-automation's MAIN branch (immutable subject).
# ---------------------------------------------------------------
data "aws_iam_policy_document" "failover_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn] # declared in ci-push.tf
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:ppmcad16a-cloud-platform@308835253/platform-automation@1439349192:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "failover" {
  name                 = "gha-failover-wake"
  assume_role_policy   = data.aws_iam_policy_document.failover_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "failover" {
  statement {
    actions   = ["eks:DescribeNodegroup", "eks:UpdateNodegroupConfig"]
    resources = ["arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:nodegroup/prod-eks/default/*"]
  }
}

resource "aws_iam_role_policy" "failover" {
  name   = "wake-eks-standby"
  role   = aws_iam_role.failover.id
  policy = data.aws_iam_policy_document.failover.json
}

output "failover_role_arn" {
  value = aws_iam_role.failover.arn
}
