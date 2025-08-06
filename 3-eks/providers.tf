# `terraform/3-eks/providers.tf`

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }

  required_version = "~> 1.5"

  backend "s3" {
    bucket         = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "zero-to-prod-aws-eks-cicd-terraform-ugp-dynamodb-table"
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# The Helm provider now uses a map argument instead of a block,
# as suggested by the error message.
provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.main.token
  }
}

data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}