# `terraform/06-ci-cd/backend/backend-ci-cd.tf`
#
# Provisions the CodePipeline and CodeBuild for the backend application.

# ----------------
# Data Sources
# ----------------
# We need to get the S3 bucket name from our '05-app-infra' module's state file.
data "terraform_remote_state" "app_infra" {
  backend = "s3"
  config = {
    bucket = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket" # !! IMPORTANT: Replace with your actual S3 backend bucket !!
    key    = "app-infra/terraform.tfstate"
    region = var.aws_region
  }
}

# Get EKS cluster details from its remote state
data "terraform_remote_state" "eks_cluster" {
  backend = "s3"
  config = {
    bucket = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket" # !! IMPORTANT: Replace with your actual S3 backend bucket !!
    key    = "eks/terraform.tfstate"                             # Assuming EKS cluster state is stored here
    region = var.aws_region
  }
}

# Get ECR repository details from its remote state (from your 4-ecr step)
data "terraform_remote_state" "ecr_repo" {
  backend = "s3"
  config = {
    bucket = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket" # !! IMPORTANT: Replace with your actual S3 backend bucket !!
    key    = "ecr/terraform.tfstate"                             # Assuming ECR state is stored here
    region = var.aws_region
  }
}

# Data source for current AWS account ID, needed for CloudWatch Logs ARN and ECR URI
data "aws_caller_identity" "current" {}


# ----------------
# CodePipeline S3 Artifact Bucket (Dedicated for Backend)
# ----------------
# This is a dedicated S3 bucket to store artifacts from the backend CodePipeline stages.
resource "aws_s3_bucket" "backend_codepipeline_artifacts" {
  bucket        = "${var.project_name}-backend-codepipeline-artifacts" # Unique name for backend artifacts
  force_destroy = true                                                 # Useful for a demo to clean up easily
  tags = {
    Name = "${var.project_name}-backend-codepipeline-artifacts"
  }
}


# ----------------
# IAM Roles for CodePipeline and CodeBuild
# ----------------

# IAM role for CodePipeline to orchestrate the pipeline
resource "aws_iam_role" "backend_pipeline_role" {
  name = "${var.project_name}-backend-pipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name = "${var.project_name}-backend-pipeline-role"
  }
}

# Policy for CodePipeline role
resource "aws_iam_role_policy" "backend_pipeline_policy" {
  name = "${var.project_name}-backend-pipeline-policy"
  role = aws_iam_role.backend_pipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:PutObject",
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.backend_codepipeline_artifacts.arn,
          "${aws_s3_bucket.backend_codepipeline_artifacts.arn}/*"
        ]
      },
      {
        # Permission to use the NEW CodeStar Connection for backend source stage
        Action = [
          "codestar-connections:UseConnection"
        ],
        Effect   = "Allow",
        Resource = aws_codestarconnections_connection.backend_github_connection.arn # Directly referencing the resource
      },
      {
        # Permissions to start and monitor CodeBuild projects
        Action = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:BatchGetBuilds",
        ],
        Effect   = "Allow",
        Resource = aws_codebuild_project.backend_build.arn # Specific to this CodeBuild project
      }
    ]
  })
}

# IAM role for CodeBuild to perform build and deployment tasks
resource "aws_iam_role" "backend_build_role" {
  name = "${var.project_name}-backend-build-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name = "${var.project_name}-backend-build-role"
  }
}

# Policy for CodeBuild role
resource "aws_iam_role_policy" "backend_build_policy" {
  name = "${var.project_name}-backend-build-policy"
  role = aws_iam_role.backend_build_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        # Permissions for CloudWatch Logs
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-backend-build:*"
      },
      {
        # Permissions for S3 artifacts (input and output)
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          aws_s3_bucket.backend_codepipeline_artifacts.arn,
          "${aws_s3_bucket.backend_codepipeline_artifacts.arn}/*"
        ]
      },
      # Permissions for ECR registry-level action
      {
        Action   = ["ecr:GetAuthorizationToken"],
        Effect   = "Allow",
        Resource = "*"
      },
      # Permissions for ECR repository-level actions
      {
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ],
        Effect   = "Allow",
        Resource = data.terraform_remote_state.ecr_repo.outputs.repository_arn
      },
      {
        # Permissions for EKS (kubectl and helm commands)
        Action = [
          "eks:DescribeCluster",
          "eks:UpdateKubeconfig",
          "ssm:GetParameters",
          "sts:AssumeRole"
        ],
        Effect   = "Allow",
        Resource = data.terraform_remote_state.eks_cluster.outputs.eks_cluster_arn
      }
    ]
  })
}


# ----------------
# CodeBuild Project
# ----------------
resource "aws_codebuild_project" "backend_build" {
  name          = "${var.project_name}-backend-build"
  service_role  = aws_iam_role.backend_build_role.arn
  build_timeout = "60" # minutes

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = data.terraform_remote_state.ecr_repo.outputs.repository_name
    }
    environment_variable {
      name  = "EKS_CLUSTER_NAME"
      value = data.terraform_remote_state.eks_cluster.outputs.eks_cluster_name
    }
    environment_variable {
      name  = "KUBERNETES_NAMESPACE"
      value = var.kubernetes_namespace
    }
    environment_variable {
      name  = "HELM_CHART_PATH"
      value = var.backend_helm_chart_path
    }
    environment_variable {
      name  = "HELM_RELEASE_NAME"
      value = var.backend_helm_release_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name = "${var.project_name}-backend-build"
  }
}

# ----------------
# CodePipeline
# ----------------
resource "aws_codepipeline" "backend_pipeline" {
  name     = "${var.project_name}-backend-pipeline"
  role_arn = aws_iam_role.backend_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.backend_codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.backend_github_connection.arn # Directly referencing the resource
        FullRepositoryId = var.backend_full_repo_id
        BranchName       = var.backend_repo_branch
      }
    }
  }

  stage {
    name = "BuildAndDeploy"
    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.backend_build.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-backend-pipeline"
  }
}
