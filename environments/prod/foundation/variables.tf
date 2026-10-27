variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "services" {
  description = "Every service that gets an image repository"
  type        = list(string)
  default = [
    "api-gateway-service",
    "identity-service",
    "catalog-service",
    "commerce-service",
    "notification-service",
    "client-service",
    "seed-db-service",
  ]
}
