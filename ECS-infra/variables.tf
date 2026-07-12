# Define your MongoDB URI as a Terraform variable to avoid hardcoding secrets
variable "mongo_uri" {
  description = "MongoDB Atlas Connection String"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "json web token"
  type        = string
  sensitive   = true
}

variable "region" {
  type = string
  default = "ap-southeast-1"
}