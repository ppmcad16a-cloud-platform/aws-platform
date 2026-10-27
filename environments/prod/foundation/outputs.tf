output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "registry" {
  description = "Registry host - images are <registry>/<service>:<tag>"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}
