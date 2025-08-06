# `terraform/05-app-infra/variables.tf`
#
# Defines the input variables for the app-infra module.

variable "project_name" {
  description = "A unique name for the project, used as a prefix for all resources."
  type        = string
  default     = "ugp-eks-cicd"
}

variable "aws_region" {
  description = "The AWS region to deploy all resources into."
  type        = string
  default     = "us-east-1"
}