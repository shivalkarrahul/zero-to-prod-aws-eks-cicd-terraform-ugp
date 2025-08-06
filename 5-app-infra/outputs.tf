# `terraform/05-app-infra/outputs.tf`
#
# Exports key values from the app-infra module.

output "frontend_ui_bucket_name" {
  description = "The name of the S3 bucket for the frontend UI."
  value       = aws_s3_bucket.frontend_ui.bucket
}

output "frontend_ui_website_endpoint" {
  description = "The S3 website endpoint for the frontend UI."
  value       = aws_s3_bucket_website_configuration.frontend_ui_website.website_endpoint
}

output "dynamodb_messages_table_name" {
  description = "The name of the DynamoDB table for application messages."
  value       = aws_dynamodb_table.messages.name
}

output "frontend_ui_bucket_arn" {
  description = "The ARN of the S3 bucket for the frontend UI."
  value       = aws_s3_bucket.frontend_ui.arn
}