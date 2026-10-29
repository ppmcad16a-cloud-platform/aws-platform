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

variable "gke_issuer" {
  description = "OIDC issuer of the GKE cluster where Jenkins runs (stable: built from project/zone/name)"
  type        = string
  default     = "https://container.googleapis.com/v1/projects/project-899ced78-a554-40c2-96c/locations/asia-south1-a/clusters/prod-gke"
}
