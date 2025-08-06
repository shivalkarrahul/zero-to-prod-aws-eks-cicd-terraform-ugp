# `terraform/3-eks/ingress-controller/main.tf`

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  version    = "4.13.0"

  depends_on = [
    data.aws_eks_cluster.my_eks_cluster
  ]
}

data "aws_eks_cluster" "my_eks_cluster" {
  name = var.eks_cluster_name
}