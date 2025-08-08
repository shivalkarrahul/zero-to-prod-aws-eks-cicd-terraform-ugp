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

# Data source to retrieve the Kubernetes service created by the ingress-nginx chart.
# This service is of type LoadBalancer and will have the AWS LB details.
data "kubernetes_service" "ingress_nginx_service" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  # This depends_on ensures we wait for the Helm chart to fully deploy
  # and create the service before we try to look it up.
  depends_on = [helm_release.ingress_nginx]
}

# This output block exports the DNS name of the Load Balancer.
# This value can be used by other modules, such as the `5-app-infra` module,
# to store it in a secure location like AWS Systems Manager Parameter Store.
output "ingress_nginx_lb_hostname" {
  description = "The hostname of the AWS Load Balancer created by the ingress-nginx controller."
  value       = data.kubernetes_service.ingress_nginx_service.status.0.load_balancer.0.ingress.0.hostname
}