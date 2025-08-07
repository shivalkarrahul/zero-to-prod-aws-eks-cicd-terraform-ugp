# `terraform/03-eks/irsa.tf`

# Find the OIDC provider for our EKS cluster
data "aws_eks_cluster" "ugp_eks" {
  name = "ugp-eks-cicd-cluster"
}

# Find the OIDC provider certificate thumbprint from its URL
data "tls_certificate" "ugp_eks_oidc" {
  url = data.aws_eks_cluster.ugp_eks.identity[0].oidc[0].issuer
}

# This is the resource that creates the OIDC Provider in IAM
resource "aws_iam_openid_connect_provider" "ugp_eks_oidc" {
  url = data.aws_eks_cluster.ugp_eks.identity[0].oidc[0].issuer

  # The audience list for the OIDC provider
  client_id_list = ["sts.amazonaws.com"]

  # Corrected: Fetch the thumbprint from the tls_certificate data source
  thumbprint_list = [data.tls_certificate.ugp_eks_oidc.certificates[0].sha1_fingerprint]
}

# Create a dedicated IAM policy for our application
resource "aws_iam_policy" "ugp_backend_policy" {
  name        = "ugp-backend-ecr-dynamodb-bedrock-policy"
  description = "Allows the backend service account to pull from ECR, access DynamoDB, and use Bedrock"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*" # ECR actions are typically global
      },
      # Permissions for DynamoDB access
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        # IMPORTANT: Restrict this to your specific DynamoDB table ARN
        Resource = "arn:aws:dynamodb:us-east-1:064827688814:table/ugp-eks-cicd-messages-table"
      },
      # ADDED: Permissions for Amazon Bedrock
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*" # Bedrock actions are typically global
      }
    ]
  })
}

# Create an IAM role for the Kubernetes service account
resource "aws_iam_role" "ugp_backend_sa_role" {
  name = "ugp-backend-sa-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.ugp_eks_oidc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.ugp_eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:default:ugp-backend-service-account"
          }
        }
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "ugp_backend_sa_policy_attach" {
  role       = aws_iam_role.ugp_backend_sa_role.name
  policy_arn = aws_iam_policy.ugp_backend_policy.arn
}
