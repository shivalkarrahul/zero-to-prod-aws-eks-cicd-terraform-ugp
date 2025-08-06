# `terraform/3-eks/ingress-controller/variables.tf`

variable "eks_cluster_name" {
  description = "The name of the EKS cluster to deploy the ingress controller to."
  type        = string
}