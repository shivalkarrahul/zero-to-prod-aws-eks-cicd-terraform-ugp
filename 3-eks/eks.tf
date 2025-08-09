# `terraform/03-eks/eks.tf`
#
# Provisions the EKS cluster and its managed node groups.

# Data source to retrieve the VPC's state file from our S3 backend
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket"
    key    = "vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

# Data source to retrieve the IAM module's state file from our S3 backend
data "terraform_remote_state" "iam" {
  backend = "s3"
  config = {
    bucket = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket"
    key    = "iam/terraform.tfstate"
    region = "us-east-1"
  }
}

# 1. EKS Cluster
# We're creating the EKS control plane itself.
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  version  = "1.33"
  role_arn = data.terraform_remote_state.iam.outputs.eks_cluster_role_arn

  vpc_config {
    subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  }

  # This timeout block is a best practice for long-running resources like EKS.
  # The default is 30m, we'll extend it just in case.
  timeouts {
    create = "45m"
    update = "60m"
    delete = "20m"
  }
}

# 2. EKS Managed Node Group
# This is the pool of EC2 instances that will run our containerized applications.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = data.terraform_remote_state.iam.outputs.eks_node_group_role_arn
  subnet_ids      = data.terraform_remote_state.vpc.outputs.private_subnet_ids
  instance_types  = ["t3.micro"]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  tags = {
    Name = "${var.project_name}-node-group"
  }
}