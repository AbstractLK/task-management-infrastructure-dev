terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket         = "task-management-test-terraform-state-860977520998"
    key            = "test/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    use_lockfile   = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}