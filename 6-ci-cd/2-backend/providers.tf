# `terraform/06-ci-cd/backend/providers.tf`
#
# Configures the AWS provider and the remote backend for the backend CI/CD module.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Ensure this matches your project's required AWS provider version
    }
  }

  required_version = "~> 1.5" # Ensure this matches your project's required Terraform version

  backend "s3" {
    bucket       = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket" # !! IMPORTANT: Use your actual S3 backend bucket name !!
    key          = "ci-cd/backend/terraform.tfstate"                   # Unique key for backend CI/CD state
    region       = "us-east-1"                                         # !! IMPORTANT: Use your actual backend region !!
    encrypt      = true
    use_lockfile = true # Recommended for state locking
  }
}

provider "aws" {
  region = var.aws_region # Uses the region defined in variables.tf
}
