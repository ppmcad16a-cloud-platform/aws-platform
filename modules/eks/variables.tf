variable "name" {
  type = string
}

variable "subnet_ids" {
  description = "PRIVATE subnets for the control plane network interfaces and the nodes"
  type        = list(string)
}

variable "admin_cidrs" {
  description = "Who may reach the Kubernetes API from the internet (kubectl)"
  type        = list(string)
}

variable "admin_principal_arns" {
  description = "IAM roles that get cluster-admin access"
  type        = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.large" # 2 vCPU, 8 GB RAM
}

variable "capacity_type" {
  description = "ON_DEMAND, or SPOT (~60-70% cheaper, but AWS can reclaim the VM)"
  type        = string
  default     = "ON_DEMAND"
}

variable "min_nodes" {
  type    = number
  default = 2
}

variable "max_nodes" {
  type    = number
  default = 3
}

variable "disk_size_gb" {
  type    = number
  default = 30
}
