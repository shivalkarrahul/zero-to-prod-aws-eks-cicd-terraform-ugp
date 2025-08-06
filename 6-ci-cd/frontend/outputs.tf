# `terraform/06-ci-cd/frontend/outputs.tf`
#
# Exports the URL of the frontend pipeline.

output "frontend_codepipeline_url" {
  description = "The URL of the AWS CodePipeline for the frontend."
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.frontend_pipeline.name}/view"
}