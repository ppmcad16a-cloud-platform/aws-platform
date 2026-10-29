# ---------------------------------------------------------------
# GitHub Actions pushes service images here - keyless.
# ONE ROLE PER SERVICE: gha-push-<service> may be used only by the
# MAIN branch of that service's repo, and may push only to that
# service's own ECR repository (no delete, no other repositories).
# ---------------------------------------------------------------
locals {
  github_org = "ppmcad16a-cloud-platform"

  # GitHub writes PERMANENT ids into the identity card ("immutable subject"):
  #   repo:<org>@<org id>/<repo>@<repo id>:ref:refs/heads/main
  # A repo that is deleted and re-created under the same name gets a NEW id,
  # so it can never inherit these permissions.
  # Look up an id with:  gh api repos/<org>/<repo> --jq .id
  github_org_id = "308835253"
  github_repo_ids = {
    "api-gateway-service"  = "1363132826"
    "identity-service"     = "1347625227"
    "catalog-service"      = "1345164391"
    "commerce-service"     = "1363104512"
    "notification-service" = "1311276453"
    "client-service"       = "1363120914"
    "seed-db-service"      = "1363165699"
  }
}

# The GitHub login provider created in bootstrap/.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "ci_push_trust" {
  for_each = toset(var.services)

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_org}@${local.github_org_id}/${each.value}@${local.github_repo_ids[each.value]}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "ci_push" {
  for_each             = toset(var.services)
  name                 = "gha-push-${each.value}"
  assume_role_policy   = data.aws_iam_policy_document.ci_push_trust[each.value].json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "ci_push" {
  for_each = toset(var.services)

  statement {
    sid       = "LoginToRegistry"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this AWS action cannot be limited to one repository
  }

  statement {
    sid = "PushOwnRepositoryOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage", # "does this tag already exist?"
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [module.ecr.repository_arns[each.value]]
  }
}

resource "aws_iam_role_policy" "ci_push" {
  for_each = toset(var.services)
  name     = "push-own-ecr-repository"
  role     = aws_iam_role.ci_push[each.value].id
  policy   = data.aws_iam_policy_document.ci_push[each.value].json
}

output "ci_push_role_arns" {
  value = { for s, r in aws_iam_role.ci_push : s => r.arn }
}
