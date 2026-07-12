# Task Management Infrastructure

Terraform infrastructure for the task management project.

This directory contains three separate infrastructure stacks:

- [EC2-infra](./EC2-infra) - single EC2-based setup for quick or manual deployment testing.
- [ECS-infra](./ECS-infra) - ECS Fargate stack with networking, ALB, IAM, SSM parameters, and container task definitions.
- [EKS-infra](./EKS-infra) - modular EKS stack built from the `modules/vpc` and `modules/eks` submodules.

## Prerequisites

- Terraform installed locally.
- AWS credentials configured for the target account.
- The required variable values available for the stack you want to deploy.

## Common Workflow

Each stack is managed from its own folder. Run Terraform commands from the folder you want to deploy.

```bash
terraform init
terraform plan
terraform apply
```

For stacks that use variables, provide values through a `terraform.tfvars` file or `-var` flags.

## Stack Notes

### EC2-infra

Creates a small public VPC, subnet, internet gateway, security group, and EC2 instance with Docker installed through user data.

### ECS-infra

Creates the ECS Fargate environment, including:

- VPC and public subnets
- Security groups for the ALB and ECS tasks
- SSM parameters for MongoDB and JWT secrets
- IAM role and policy attachments for ECS tasks
- Application Load Balancer and target group
- ECS cluster and task definition

This stack expects values for `mongo_uri` and `jwt_secret`.

### EKS-infra

Uses reusable modules to provision:

- VPC networking
- EKS cluster resources
- Public and private subnets for Kubernetes workloads

The stack is parameterized through `variables.tf` and uses the module outputs from `modules/vpc` and `modules/eks`.

## Deployment Tips

- Keep `terraform.tfvars` out of version control.
- Review the generated plan before applying changes.
- Use the `DEPLOYMENT.md` files in `ECS-infra` and `EKS-infra` for the manual AWS console deployment guides.