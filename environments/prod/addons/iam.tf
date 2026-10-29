# Every role below may ONLY be used by the EKS Pod Identity service, on
# behalf of one specific Kubernetes service account (the "association").
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ---------------------------------------------------------------
# 1. AWS Load Balancer Controller
#    Uses the controller's OFFICIAL policy, downloaded at the exact pinned version.
# ---------------------------------------------------------------
data "http" "lbc_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v${var.lb_controller_version}/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name   = "${var.cluster_name}-aws-load-balancer-controller"
  policy = data.http.lbc_policy.response_body
}

resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}

# ---------------------------------------------------------------
# 2. External Secrets: read ONLY /mern/* parameters (and decrypt them)
# ---------------------------------------------------------------
data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm" # AWS-managed key that encrypts SecureString parameters
}

data "aws_iam_policy_document" "eso" {
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/mern/*"]
  }
  statement {
    actions   = ["kms:Decrypt"]
    resources = [data.aws_kms_alias.ssm.target_key_arn]
  }
}

resource "aws_iam_role" "eso" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy" "eso" {
  name   = "read-mern-parameters"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso.json
}

resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = var.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn
}

# ---------------------------------------------------------------
# 3. EBS CSI driver (creates disks for Prometheus/Loki), as an EKS add-on
# ---------------------------------------------------------------
resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = var.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"

  pod_identity_association {
    role_arn        = aws_iam_role.ebs_csi.arn
    service_account = "ebs-csi-controller-sa"
  }
}

# ---------------------------------------------------------------
# 4. Jenkins (from GKE): enters the cluster as group "mern-deployers"
#    (bound to the mern-deployer Role by the platform-config chart)
# ---------------------------------------------------------------
data "aws_iam_role" "jenkins_deployer" {
  name = "jenkins-deployer-from-gke"
}

resource "aws_eks_access_entry" "jenkins" {
  cluster_name      = var.cluster_name
  principal_arn     = data.aws_iam_role.jenkins_deployer.arn
  kubernetes_groups = ["mern-deployers"]
  type              = "STANDARD"
}
