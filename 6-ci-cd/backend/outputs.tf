# `terraform/06-ci-cd/backend/outputs.tf`
#
# Exports the URL of the backend pipeline.

output "backend_codepipeline_url" {
  description = "The URL of the AWS CodePipeline for the backend."
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.backend_pipeline.name}/view"
}
