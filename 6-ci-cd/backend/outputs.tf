# `terraform/06-ci-cd/backend/outputs.tf`
#
# Exports the URL of the backend pipeline.

output "backend_codepipeline_url" {
  description = "The URL of the AWS CodePipeline for the backend."
  value       = "https://${var.aws_region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${aws_codepipeline.backend_pipeline.name}/view"
}

output "manual_configmap_update_instructions" {
  description = "Manual instructions to update the EKS 'aws-auth' ConfigMap with the new CodeBuild IAM role."
  value = <<-EOT
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
