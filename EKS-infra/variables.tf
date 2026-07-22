variable "cluster_name" {
  type = string
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
  type = list(string)
  default = ["t3.small"]
}

variable "mongodb_uri" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}