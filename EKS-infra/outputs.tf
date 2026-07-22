output "cluster_endpoint" {
  description = "The connection endpoint for the EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The name of your Kubernetes cluster"
  value       = module.eks.cluster_name
}

output "eso_iam_role_arn" {
  description = "The ARN of the IAM role to attach to the ServiceAccount in your Helm Chart"
  value       = aws_iam_role.eso_role.arn
}