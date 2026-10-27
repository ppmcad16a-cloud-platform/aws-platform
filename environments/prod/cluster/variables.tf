variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "admin_cidr" {
  description = "YOUR public IP as x.x.x.x/32 - set it in terraform.tfvars"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
  default     = "ON_DEMAND"
}
