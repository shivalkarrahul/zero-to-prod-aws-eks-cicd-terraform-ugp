# `terraform/02-iam/outputs.tf`
#
# Exports the ARNs of the IAM roles created, to be consumed by other modules.

output "eks_cluster_role_arn" {
  description = "The ARN of the IAM role for the EKS cluster."
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_group_role_arn" {
  description = "The ARN of the IAM role for the EKS worker nodes."
  value       = aws_iam_role.eks_node_group_role.arn
}