# `terraform/06-ci-cd/1-frontend/variables.tf`
#
# Defines the input variables for the frontend CI/CD module.

variable "project_name" {
  description = "The name of the project. Used as a prefix for resource names."
  type        = string
  default     = "ugp-eks-cicd"
}

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "frontend_repo_name" {
  description = "The name of the frontend Git repository."
  type        = string
  default     = "zero-to-prod-aws-eks-cicd-frontend-ugp"
}

variable "frontend_repo_branch" {
  description = "The branch of the frontend Git repository to build from."
  type        = string
  default     = "main"
}

variable "frontend_full_repo_id" {
  description = "The full GitHub repository ID (e.g., 'username/repo-name')."
  type        = string
  default     = "shivalkarrahul/zero-to-prod-aws-eks-cicd-frontend-ugp"
}

variable "notification_email" {
  description = "The email address to receive manual approval notifications."
  type        = string
  # A default value can be set for a test environment, but for a real-world
  # production setup, you should provide this value via a tfvars file.
  default = "rahulshivalkar9665196@gmail.com"
}