data "http" "cloudflare_ipv4" {
  url = "https://www.cloudflare.com/ips-v4"
}

locals {
  cloudflare_cidrs = [
    for line in split("\n", trimspace(data.http.cloudflare_ipv4.response_body)) :
    trimspace(line) if trimspace(line) != ""
  ]
  cluster_outputs = data.terraform_remote_state.cluster.outputs
}

# 1. AWS Load Balancer Controller. Installed FIRST: it adds a webhook that
#    checks every new Service, so everything else must come after it.
resource "helm_release" "aws_lbc" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.lb_controller_version
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  values = [yamlencode({
    clusterName  = var.cluster_name
    region       = var.aws_region
    vpcId        = local.cluster_outputs.vpc_id
    replicaCount = 1
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller" # matches the Pod Identity association
    }
  })]

  depends_on = [aws_eks_pod_identity_association.lbc, aws_iam_role_policy_attachment.lbc]
}

resource "helm_release" "envoy_gateway" {
  name             = "envoy-gateway"
  repository       = "oci://docker.io/envoyproxy"
  chart            = "gateway-helm"
  version          = var.envoy_gateway_version
  namespace        = "envoy-gateway-system"
  create_namespace = true
  wait             = true
  timeout          = 600
  depends_on       = [helm_release.aws_lbc]
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_version
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 600
  # No annotations needed: the Pod Identity association links the role.
  depends_on = [helm_release.aws_lbc, aws_eks_pod_identity_association.eso]
}

# Teardown safety: on DESTROY, wait 90s after the front door is removed so
# the LB controller (still running) can delete the AWS load balancer.
# Otherwise the NLB is orphaned and blocks deleting the VPC.
resource "time_sleep" "lb_cleanup" {
  destroy_duration = "90s"
  depends_on       = [helm_release.aws_lbc, helm_release.envoy_gateway]
}

# Teardown safety: on DESTROY, after Prometheus/Loki are removed, WAIT until
# Kubernetes has actually deleted their disks (PersistentVolumes) - while the
# EBS CSI driver is still running. Prometheus may take minutes to stop, so we
# wait for the real event instead of guessing a duration.
#
# A destroy-time provisioner runs a command on YOUR machine when this resource
# is destroyed. It uses its own temporary kubeconfig (inside .terraform/, which
# git ignores), so it always talks to the right cluster.
resource "terraform_data" "volume_cleanup" {
  input = {
    cluster = var.cluster_name
    region  = var.aws_region
    config  = "${path.module}/.terraform/kubeconfig-destroy"
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "aws eks update-kubeconfig --name ${self.input.cluster} --region ${self.input.region} --kubeconfig ${self.input.config} && kubectl --kubeconfig ${self.input.config} wait --for=delete pv --all --timeout=900s"
    on_failure = continue # e.g. "no PVs left" - nothing to wait for, carry on
  }

  depends_on = [aws_eks_addon.ebs_csi, helm_release.platform_config]
}

resource "helm_release" "platform_config" {
  name      = "platform-config"
  chart     = "${path.module}/charts/platform-config"
  namespace = "envoy-gateway-system"
  wait      = true

  values = [yamlencode({
    cloud = "aws"
    serviceAnnotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"            = "external" # handled by the LB controller
      "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"       # send straight to pod IPs
      "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
      "service.beta.kubernetes.io/aws-load-balancer-subnets"         = local.cluster_outputs.public_subnet_ids[0]
      "service.beta.kubernetes.io/aws-load-balancer-eip-allocations" = local.cluster_outputs.ingress_eip_allocation_id
      "service.beta.kubernetes.io/aws-load-balancer-attributes"      = "load_balancing.cross_zone.enabled=true"
    }
    sourceRanges = concat(local.cloudflare_cidrs, [var.admin_cidr])
    secretStore = {
      aws = {
        service = "ParameterStore"
        region  = var.aws_region
        # Our parameters are "/mern/mern-mongo-uri" etc.; with this prefix
        # the SAME key names ("mern-mongo-uri") work as in GCP and Azure.
        prefix = "/mern/"
      }
    }
    defaultStorageClass = {
      name        = "gp3"
      provisioner = "ebs.csi.aws.com"
      parameters = {
        type      = "gp3"
        encrypted = "true"
      }
    }
    deployerSubjects = [
      {
        kind     = "Group"
        apiGroup = "rbac.authorization.k8s.io"
        name     = "mern-deployers"
      },
    ]
  })]

  depends_on = [
    time_sleep.lb_cleanup,
    helm_release.external_secrets,
    aws_iam_role_policy.eso,
    aws_eks_addon.ebs_csi,
  ]
}
