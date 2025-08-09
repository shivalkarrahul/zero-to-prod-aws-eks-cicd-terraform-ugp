# `terraform/06-ci-cd/frontend/frontend-ci-cd.tf`
#
# Provisions the CodePipeline and CodeBuild for the frontend UI.

# ----------------
# Data Sources
# ----------------
# We need to get the S3 bucket name from our '05-app-infra' module's state file.
data "terraform_remote_state" "app_infra" {
  backend = "s3"
  config = {
    bucket = "zero-to-prod-aws-eks-cicd-terraform-ugp-s3-bucket"
    key    = "app-infra/terraform.tfstate"
    region = var.aws_region
  }
}

# Add a data source to retrieve the value of the SSM parameter
# that was created in the `05-app-infra` module.
data "aws_ssm_parameter" "backend_api_host" {
  name = "/${var.project_name}/backend-api-host"
}


# ----------------
# CodePipeline S3 Artifact Bucket
# ----------------
# This is a dedicated S3 bucket to store artifacts from the CodePipeline stages.
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "${var.project_name}-codepipeline-artifacts"
  force_destroy = true # Useful for a demo to clean up easily
  tags = {
    Name = "${var.project_name}-codepipeline-artifacts"
  }
}


# ----------------
# IAM Roles for CodePipeline and CodeBuild
# ----------------
resource "aws_iam_role" "frontend_pipeline_role" {
  name = "${var.project_name}-frontend-pipeline-role"
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
}

resource "aws_iam_role_policy" "frontend_pipeline_policy" {
  name = "${var.project_name}-frontend-pipeline-policy"
  role = aws_iam_role.frontend_pipeline_role.id
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
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Action = [
          "codestar-connections:UseConnection"
        ],
        Effect   = "Allow",
        Resource = aws_codestarconnections_connection.github_connection.arn
      },
      {
        Action = [
          "codebuild:StartBuild",
          "codebuild:StopBuild",
          "codebuild:BatchGetBuilds",
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "frontend_build_role" {
  name = "${var.project_name}-frontend-build-role"
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
}

resource "aws_iam_role_policy" "frontend_build_policy" {
  name = "${var.project_name}-frontend-build-policy"
  role = aws_iam_role.frontend_build_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.project_name}-frontend-build:*"
      },
      {
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
          data.terraform_remote_state.app_infra.outputs.frontend_ui_bucket_arn,
          "${data.terraform_remote_state.app_infra.outputs.frontend_ui_bucket_arn}/*",
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Action   = "ssm:GetParameter",
        Effect   = "Allow",
        Resource = data.aws_ssm_parameter.backend_api_host.arn
      }
    ]
  })
}

# ----------------
# CodeBuild Project
# ----------------
resource "aws_codebuild_project" "frontend_build" {
  name          = "${var.project_name}-frontend-build"
  service_role  = aws_iam_role.frontend_build_role.arn
  build_timeout = "60"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = false
    image_pull_credentials_type = "CODEBUILD"

    # This is the corrected placement for the environment_variables block
    environment_variable {
      name  = "S3_BUCKET_NAME"
      value = data.terraform_remote_state.app_infra.outputs.frontend_ui_bucket_name
    }

    # New environment variable to pass the backend API host to the build.
    environment_variable {
      name  = "REACT_APP_API_HOST"
      value = data.aws_ssm_parameter.backend_api_host.value
    }

  }



  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# ----------------
# CodePipeline
# ----------------
resource "aws_codepipeline" "frontend_pipeline" {
  name     = "${var.project_name}-frontend-pipeline"
  role_arn = aws_iam_role.frontend_pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name     = "Source"
      category = "Source"
      # Use 'ThirdParty' owner and 'CodeStarSourceConnection' provider for GitHub
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        # The ARN of the connection created in connection.tf
        ConnectionArn = aws_codestarconnections_connection.github_connection.arn
        # Your full GitHub repository name (e.g., my-github-username/my-repo-name)
        FullRepositoryId = var.frontend_full_repo_id
        # The branch to trigger the pipeline from
        BranchName = var.frontend_repo_branch
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
      version         = "1"
      configuration = {
        ProjectName = aws_codebuild_project.frontend_build.name
      }
    }
  }
}