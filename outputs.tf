output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks-cluster.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks-cluster.cluster_name
}

output "region" {
  description = "AWS region"
  value     = var.region
}

output "public_hostname" {
  description = "webpage public hostname"
  value       = data.kubernetes_service_v1.webpage-load-balancer.status[0].load_balancer[0].ingress[0].hostname
}