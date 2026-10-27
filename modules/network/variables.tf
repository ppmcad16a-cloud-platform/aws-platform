variable "name" {
  type = string
}

variable "cidr" {
  description = "Whole IP range of the VPC"
  type        = string
}

variable "az_count" {
  description = "EKS requires subnets in at least 2 availability zones"
  type        = number
  default     = 2
}
