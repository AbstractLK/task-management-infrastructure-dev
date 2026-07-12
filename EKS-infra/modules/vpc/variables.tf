variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster for subnet tagging"
}