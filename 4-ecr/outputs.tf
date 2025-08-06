# `terraform/04-ecr/outputs.tf`
#
# Exports the key values for the ECR repository.

output "repository_url" {
  description = "The URI of the ECR repository."
  value       = aws_ecr_repository.backend.repository_url
}

output "repository_name" {
  description = "The name of the ECR repository."
  value       = aws_ecr_repository.backend.name
}