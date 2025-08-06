# `terraform/01-vpc/variables.tf`
#
# Defines the input variables for the VPC module.

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

variable "vpc_cidr_block" {
  description = "The CIDR block for the new VPC."
  type        = string
  default     = "10.0.0.0/16"
}