# ---------------------------------------------------------------
# IAM role for the EKS control plane (AWS manages it on our behalf)
# ---------------------------------------------------------------
data "aws_iam_policy_document" "cluster_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_trust.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn

  # Who can log in is controlled by "access entries" (below), not by the
  # old aws-auth ConfigMap. The creator does NOT get hidden admin rights.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  # COST: "STANDARD" support only. "EXTENDED" (older Kubernetes versions)
  # costs 6x more per hour.
  upgrade_policy {
    support_type = "STANDARD"
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true            # nodes talk to the API privately
    endpoint_public_access  = true            # kubectl from your laptop ...
    public_access_cidrs     = var.admin_cidrs # ... but ONLY from your IP
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ---------------------------------------------------------------
# Who is cluster admin: an "access entry" per IAM role
# ---------------------------------------------------------------
resource "aws_eks_access_entry" "admins" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "admins" {
  for_each      = toset(var.admin_principal_arns)
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}

# ---------------------------------------------------------------
# Worker nodes
# ---------------------------------------------------------------
data "aws_iam_policy_document" "node_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_trust.json
}

# Exactly what a node needs: join the cluster, run pod networking,
# and PULL (read-only) images from ECR.
resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.instance_type]
  capacity_type   = var.capacity_type
  ami_type        = "AL2023_x86_64_STANDARD"
  disk_size       = var.disk_size_gb

  scaling_config {
    desired_size = var.min_nodes
    min_size     = var.min_nodes
    max_size     = var.max_nodes
  }

  # Replace nodes one at a time during upgrades.
  update_config {
    max_unavailable = 1
  }

  labels = {
    pool = "default"
  }

  # Sleep/wake (stopped standby) is done by platform-automation's standby.yml
  # and wake.yml, like starting/stopping an EC2 instance. Terraform creates
  # the group with min_nodes, then leaves the node COUNT alone - otherwise
  # the next plan would wake a sleeping standby by itself.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size, scaling_config[0].min_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}

# ---------------------------------------------------------------
# Core add-ons, managed and patched by AWS
# ---------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  # Turn on enforcement of Kubernetes NetworkPolicies (Phase 6).
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
}

# EKS Pod Identity: pods log in to AWS (e.g. Secrets Manager) without keys.
resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
}

# CoreDNS runs as pods, so it needs nodes first.
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.default]
}
