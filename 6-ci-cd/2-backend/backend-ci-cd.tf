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
        Resource = "*"
      },
      # NEW STATEMENT: Add permission to publish to the SNS topic for manual approval
      {
        Action   = "sns:Publish",
        Effect   = "Allow",
        Resource = aws_sns_topic.backend_approval_topic.arn
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
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-backend-lint:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-backend-build:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-backend-deploy:*"
        ]
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
# New CodeBuild Project (Linting)
# ----------------
resource "aws_codebuild_project" "backend_lint_project" {
  name          = "${var.project_name}-backend-lint"
  service_role  = aws_iam_role.backend_build_role.arn
  build_timeout = "10" # minutes

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false # No Docker required for linting
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-lint.yml" # Pointing to the new linting buildspec
  }

  tags = {
    Name = "${var.project_name}-backend-lint"
  }
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
# CodeBuild Project (Deployment)
# ----------------
resource "aws_codebuild_project" "backend_deploy_project" {
  name          = "${var.project_name}-backend-deploy"
  service_role  = aws_iam_role.backend_build_role.arn
  build_timeout = "20" # minutes

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # Required for kubectl and helm
    image_pull_credentials_type = "CODEBUILD"

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
    buildspec = "deploy.buildspec.yml"
  }

  tags = {
    Name = "${var.project_name}-backend-deploy"
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
    name = "Lint"
    action {
      name            = "Lint"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.backend_lint_project.name
      }
    }
  }

  stage {
    name = "Build"
    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"] # <-- ADD THIS LINE
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.backend_build.name
      }
    }
  }

  stage {
    name = "ManualApproval"
    action {
      name     = "ApproveDeployment"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        NotificationArn = aws_sns_topic.backend_approval_topic.arn
        CustomData      = "Approval required for the latest backend build. Verify the build artifacts before proceeding with deployment to production."
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact", "BuildArtifact"]
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.backend_deploy_project.name
        PrimarySource = "SourceArtifact"
      }
    }
  }    

  tags = {
    Name = "${var.project_name}-backend-pipeline"
  }
}

# ----------------
# SNS Topic and Subscription for Manual Approval
# ----------------
# This SNS topic will be used to send notifications when the pipeline reaches the
# manual approval stage.
resource "aws_sns_topic" "backend_approval_topic" {
  name = "${var.project_name}-backend-approval"
  tags = {
    Name = "${var.project_name}-backend-approval"
  }
}

# This resource subscribes the specified email to the SNS topic.
resource "aws_sns_topic_subscription" "backend_approval_email_subscription" {
  topic_arn = aws_sns_topic.backend_approval_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# ----------------
# CodeStar Notification Rule for All Pipeline Events
# ----------------
resource "aws_codestarnotifications_notification_rule" "backend_pipeline_notifications" {
  name     = "${var.project_name}-backend-pipeline-events"
  resource = aws_codepipeline.backend_pipeline.arn

  detail_type = "BASIC"

  target {
    address = aws_sns_topic.backend_approval_topic.arn
    type    = "SNS"
  }

  event_type_ids = [
    # Pipeline Execution Events
    "codepipeline-pipeline-pipeline-execution-started",
    "codepipeline-pipeline-pipeline-execution-succeeded",
    "codepipeline-pipeline-pipeline-execution-failed",
    "codepipeline-pipeline-pipeline-execution-superseded",

    # Manual Approval Events
    "codepipeline-pipeline-manual-approval-needed",
    "codepipeline-pipeline-manual-approval-succeeded",
    "codepipeline-pipeline-manual-approval-failed",
  ]

  status = "ENABLED"

  tags = {
    Name = "${var.project_name}-backend-pipeline-events"
  }
}


# ----------------
# Combined IAM Policy for the SNS Topic
# ----------------
# This data source defines a single policy document that grants BOTH
# CodePipeline and CodeStar Notifications the permission to publish.
data "aws_iam_policy_document" "combined_backend_sns_publish_policy" {
  statement {
    sid     = "AllowCodePipelinePublish"
    effect  = "Allow"
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    resources = [aws_sns_topic.backend_approval_topic.arn]
  }

  statement {
    sid     = "AllowCodeStarNotificationsPublish"
    effect  = "Allow"
    actions = ["sns:Publish"]

    principals {
      type        = "Service"
      identifiers = ["codestar-notifications.amazonaws.com"]
    }

    resources = [aws_sns_topic.backend_approval_topic.arn]
  }
}

# This resource attaches the complete, combined policy to the SNS topic.
resource "aws_sns_topic_policy" "backend_approval_topic_policy" {
  arn    = aws_sns_topic.backend_approval_topic.arn
  policy = data.aws_iam_policy_document.combined_backend_sns_publish_policy.json
}
