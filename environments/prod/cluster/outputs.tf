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

output "ingress_ip" {
  description = "Public IP of the web entrance - Cloudflare's origin for AWS"
  value       = aws_eip.ingress.public_ip
}

output "ingress_eip_allocation_id" {
  value = aws_eip.ingress.allocation_id
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}
