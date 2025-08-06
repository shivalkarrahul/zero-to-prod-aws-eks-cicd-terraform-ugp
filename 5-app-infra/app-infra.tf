# `terraform/05-app-infra/app-infra.tf`
#
# Provisions an S3 bucket for frontend static hosting and a DynamoDB table for the backend.

# -----------------
# S3 Bucket for UI
# -----------------
resource "aws_s3_bucket" "frontend_ui" {
  bucket = "${var.project_name}-frontend-ui-bucket"
  tags = {
    Name = "${var.project_name}-frontend-ui-bucket"
  }
}

# Configure S3 for static website hosting
resource "aws_s3_bucket_website_configuration" "frontend_ui_website" {
  bucket = aws_s3_bucket.frontend_ui.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

# This resource ensures that the public access is managed by a bucket policy
resource "aws_s3_bucket_public_access_block" "frontend_ui_public_access_block" {
  bucket                  = aws_s3_bucket.frontend_ui.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = false
  restrict_public_buckets = false
}

# This policy grants read-only access to all objects in the bucket
resource "aws_s3_bucket_policy" "frontend_ui_policy" {
  bucket = aws_s3_bucket.frontend_ui.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": [
          "${aws_s3_bucket.frontend_ui.arn}/*",
        ]
      }
    ]
  })
}

# CORS configuration to allow the frontend to make API calls to a different domain
resource "aws_s3_bucket_cors_configuration" "frontend_ui_cors" {
  bucket = aws_s3_bucket.frontend_ui.id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD", "POST"]
    allowed_origins = ["*"] # Be more restrictive in production
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# -----------------
# DynamoDB Table
# -----------------
resource "aws_dynamodb_table" "messages" {
  name             = "${var.project_name}-messages-table"
  billing_mode     = "PAY_PER_REQUEST" # Serverless mode, great for demos
  hash_key         = "id"

  attribute {
    name = "id"
    type = "S" # String type
  }

  tags = {
    Name = "${var.project_name}-messages-table"
  }
}