variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.36"
  description = "The Kubernetes version for the EKS control plane"
}

variable "all_subnet_ids" {
  type        = list(string)
  description = "List of all subnet IDs (public and private) for the cluster control plane"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where worker nodes will sit"
}

variable "desired_size" {
  type = number
  default = 2
}

variable "max_size" {
  type = number
  default = 3
}

variable "min_size" {
  type = number
  default = 1
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.small"]
  description = "The EC2 instance type for the EKS worker nodes"
}