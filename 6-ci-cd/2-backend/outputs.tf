# `terraform/06-ci-cd/2-backend/outputs.tf`
#
# Exports the URL of the backend pipeline.

output "backend_codepipeline_url" {
  description = "The URL of the AWS CodePipeline for the backend."
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.backend_pipeline.name}/view"
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
     "${aws_codestarconnections_connection.backend_github_connection.name}". 
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

You will also need to perform these same steps for the frontend connection.     

  ==============================================================
  EOT
}

output "manual_configmap_update_instructions" {
  description = "Manual instructions to update the EKS 'aws-auth' ConfigMap with the new CodeBuild IAM role."
  value       = <<-EOT
  ==============================================================
  MANUAL STEP REQUIRED: UPDATE EKS 'aws-auth' CONFIGMAP
  ==============================================================
  Your Terraform configuration has successfully created the CodeBuild
  IAM role that needs access to your EKS cluster. However, the
  'aws-auth' ConfigMap is not managed by this Terraform
  configuration.

  You must manually add the CodeBuild IAM role to the 'aws-auth'
  ConfigMap to grant it cluster administrator permissions.

  1. **Configure your AWS CLI.** Before running any `aws` or `kubectl`
     commands, you must ensure your local AWS CLI is configured with
     your credentials. Choose one of the following methods:

     **Option A: Use `aws configure`**
     This is the most common method and saves your credentials
     persistently.

     aws configure

     **Option B: Export Environment Variables**
     This is useful for one-off sessions or scripting. Replace the
     placeholder values with your actual credentials.

     export AWS_ACCESS_KEY_ID="<your_access_key_id>"
     export AWS_SECRET_ACCESS_KEY="<your_secret_access_key>"
     export AWS_DEFAULT_REGION="${var.aws_region}"

  2. **Get the EKS cluster kubeconfig.** This command will add a context to your
     local kubeconfig file, allowing you to run 'kubectl' commands
     against your EKS cluster.

     aws eks update-kubeconfig --region ${var.aws_region} --name ${data.terraform_remote_state.eks_cluster.outputs.eks_cluster_name}

  3. **Open the ConfigMap for editing.**

     kubectl edit configmap aws-auth -n kube-system

  4. **Add the following YAML snippet** under the **'mapRoles'** section:

     - rolearn: ${aws_iam_role.backend_build_role.arn}
       username: ugp-backend-build-role
       groups:
       - system:masters

  5. Save and close the editor. Your CodeBuild project will now
     have permission to interact with the EKS cluster.
  ==============================================================
  EOT
}
