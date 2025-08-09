# `terraform/06-ci-cd/1-frontend/outputs.tf`
#
# Exports the URL of the frontend pipeline.

output "frontend_codepipeline_url" {
  description = "The URL of the AWS CodePipeline for the frontend."
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.frontend_pipeline.name}/view"
}

output "manual_codestar_approval" {
  description = "Manual instructions to approve the AWS CodeStar connection."
  value       = <<-EOT
  ==============================================================
  MANUAL STEP REQUIRED: APPROVE CODESTAR CONNECTION
  ==============================================================
  Your Terraform configuration has created a CodeStar connection
  that is currently in a 'PENDING' state. This requires a one-time
  manual approval to connect your AWS account to your GitHub repository.

  1. **Go to the AWS Console.** Navigate to 'Developer Tools' ->
     'Settings' -> 'Connections'.

  2. **Find the connection.** Locate the connection named
     "${aws_codestarconnections_connection.github_connection.name}". 
     You will see its status is 'Pending'.

  3. **Approve the connection.** Click on the connection and then
     click the 'Update pending connection' button. You will be
     redirected to GitHub to authorize the connection.
     Here, you'll either be prompted to install the AWS Connector for GitHub application 
     or to use the one that's already installed for your organization. 
     This action grants AWS the necessary permissions to your repository.


  4. **Run 'terraform apply' again.** Once the connection's status
     in the AWS console changes to 'Available', you can run
     'terraform apply' once more. This will allow Terraform to
     create any dependent resources, such as the CodePipeline.

You will also need to perform these same steps for the backend connection.     

  ==============================================================
  EOT
}