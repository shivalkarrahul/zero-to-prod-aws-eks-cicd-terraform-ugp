# `terraform/04-ecr/ecr.tf`
#
# Provisions a private ECR repository for the backend API.

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend-repository"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-backend-repository"
  }
}

# Optional: Lifecycle policy to clean up old, untagged images
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description = "Expire untagged images",
        selection = {
          tagStatus = "untagged"
          countType = "imageCountMoreThan"
          countNumber = 1
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}