# `terraform/06-ci-cd/backend/connection.tf`
#
# Creates a CodeStar Connection to GitHub specifically for the backend.

resource "aws_codestarconnections_connection" "backend_github_connection" {
  name          = "${var.project_name}-be-github-con" # Unique name for backend connection
  provider_type = "GitHub"
}

output "backend_github_connection_arn" {
  description = "The ARN of the AWS CodeStar Connection for the backend GitHub repository."
  value       = aws_codestarconnections_connection.backend_github_connection.arn
}
