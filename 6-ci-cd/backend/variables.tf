# `terraform/06-ci-cd/backend/variables.tf`
#
# Defines the input variables for the backend CI/CD module.

variable "project_name" {
  description = "The name of the project. Used as a prefix for resource names."
  type        = string
  default     = "ugp-eks-cicd" # Consistent with your frontend example
}

variable "aws_region" {
  description = "The AWS region to deploy resources into."
  type        = string
  default     = "us-east-1" # Consistent with your frontend example
}

variable "backend_full_repo_id" {
  description = "The full GitHub repository ID for the backend (e.g., 'username/repo-name')."
  type        = string
  default     = "shivalkarrahul/zero-to-prod-aws-eks-cicd-backend-ugp"
}

variable "backend_repo_branch" {
  description = "The branch of the backend Git repository to build from."
  type        = string
  default     = "main"
}

variable "kubernetes_namespace" {
  description = "The Kubernetes namespace where the backend will be deployed."
  type        = string
  default     = "default" # Or your specific namespace like 'quotes-app'
}

variable "backend_helm_chart_path" {
  description = "The path to the backend Helm chart within the repository (e.g., 'ugp-backend-chart')."
  type        = string
  default     = "ugp-backend-chart" # Based on your repo structure
}

variable "backend_helm_release_name" {
  description = "The Helm release name for the backend application."
  type        = string
  default     = "ugp-backend"
}
