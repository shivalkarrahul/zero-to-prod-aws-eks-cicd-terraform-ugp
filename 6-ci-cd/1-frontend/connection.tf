# `terraform/06-ci-cd/frontend/connection.tf`
#
# Creates a CodeStar Connection to GitHub to be used by CodePipeline.

resource "aws_codestarconnections_connection" "github_connection" {
  name          = "${var.project_name}-github-connection"
  provider_type = "GitHub"
}

output "github_connection_arn" {
  value = aws_codestarconnections_connection.github_connection.arn
}