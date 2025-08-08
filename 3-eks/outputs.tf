# `terraform/03-eks/outputs.tf`
#
# Exports the key values for the EKS cluster.

output "eks_cluster_name" {
  description = "The name of the EKS cluster."
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the EKS cluster's API server."
  value       = aws_eks_cluster.main.endpoint
}

output "ugp_backend_sa_role_arn" {
  value = aws_iam_role.ugp_backend_sa_role.arn
}

# Add this to your existing terraform/03-eks/outputs.tf
output "eks_cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.main.arn # Assuming 'main' is your aws_eks_cluster resource name
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.main.certificate_authority.0.data
}

output "ingress_nginx_lb_hostname" {
  description = "The hostname of the AWS Load Balancer created by the ingress-nginx controller."
  value       = module.ingress_controller.ingress_nginx_lb_hostname
}