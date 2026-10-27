output "repository_urls" {
  description = "service name => push/pull URL"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  value = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
