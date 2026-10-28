variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "prod-eks"
}

variable "admin_cidr" {
  description = "YOUR public IP x.x.x.x/32 - may reach the front door directly for testing"
  type        = string
}

variable "envoy_gateway_version" {
  type    = string
  default = "v1.9.2"
}

variable "external_secrets_version" {
  type    = string
  default = "2.12.0"
}

variable "lb_controller_version" {
  description = "AWS Load Balancer Controller (chart version = app version)"
  type        = string
  default     = "3.6.0"
}
