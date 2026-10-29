# ---------------------------------------------------------------
# who may touch the database backups (S3 copy) - keyless:
# the same GKE identity provider as Jenkins' deployer (jenkins-identity.tf),
# one role per Kubernetes service account in GKE's "jenkins" namespace.
#   mongo-backup-from-gke  : PutObject only (no read, no delete)
#   mongo-restore-from-gke : ListBucket + GetObject only
# ---------------------------------------------------------------
locals {
  dr_roles = {
    "mongo-backup" = [
      { actions = ["s3:PutObject"], resources = ["${aws_s3_bucket.backups.arn}/*"] },
    ]
    "mongo-restore" = [
      { actions = ["s3:ListBucket"], resources = [aws_s3_bucket.backups.arn] },
      { actions = ["s3:GetObject"], resources = ["${aws_s3_bucket.backups.arn}/*"] },
    ]
  }
}

data "aws_iam_policy_document" "dr_trust" {
  for_each = local.dr_roles
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
      values   = ["system:serviceaccount:jenkins:${each.key}"]
    }
  }
}

resource "aws_iam_role" "dr" {
  for_each             = local.dr_roles
  name                 = "${each.key}-from-gke"
  assume_role_policy   = data.aws_iam_policy_document.dr_trust[each.key].json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "dr" {
  for_each = local.dr_roles
  dynamic "statement" {
    for_each = each.value
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "dr" {
  for_each = local.dr_roles
  name     = "mongo-backups-bucket"
  role     = aws_iam_role.dr[each.key].id
  policy   = data.aws_iam_policy_document.dr[each.key].json
}

output "dr_role_arns" {
  value = { for k, r in aws_iam_role.dr : k => r.arn }
}
