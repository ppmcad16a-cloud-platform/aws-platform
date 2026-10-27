output "cluster_name" {
  value = module.eks.cluster_name
}

output "egress_ip" {
  description = "Add this to the MongoDB Atlas IP access list (Phase 5)"
  value       = module.network.egress_ip
}

output "get_credentials" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile HeroviredProfile"
}
