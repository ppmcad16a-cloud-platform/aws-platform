variable "repository_names" {
  description = "One image repository per service"
  type        = list(string)
}

variable "keep_last_images" {
  type    = number
  default = 10
}
