# `terraform/03-eks/variables.tf`
#
# Defines the input variables for the EKS module.

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