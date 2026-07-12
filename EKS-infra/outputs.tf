output "cluster_endpoint" {
  description = "The connection endpoint for the EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "The name of your Kubernetes cluster"
  value       = module.eks.cluster_name
}