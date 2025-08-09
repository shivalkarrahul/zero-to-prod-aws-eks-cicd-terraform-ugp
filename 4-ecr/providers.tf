# `terraform/04-ecr/providers.tf`
#
# Configures the AWS provider and the remote backend for the ECR module.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = "~> 1.5"

  backend "s3" {
    bucket         = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket"
    key            = "ecr/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "zero-to-prod-aws-eks-cicd-terraform-ugp-dynamodb-table"
  }
}

provider "aws" {
  region = var.aws_region
}