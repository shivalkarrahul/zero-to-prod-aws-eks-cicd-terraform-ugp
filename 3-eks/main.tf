# `terraform/3-eks/main.tf`
#
# This file acts as the root of the EKS module.
# It provisions the EKS cluster and then calls the submodule to install
# the NGINX Ingress Controller.

# Call the submodule to provision the NGINX Ingress Controller
module "ingress_controller" {
  source = "./ingress-controller"

  # Pass the cluster name to the submodule
  eks_cluster_name = aws_eks_cluster.main.name

  # This dependency ensures the cluster is created before the ingress controller
  depends_on = [
    aws_eks_cluster.main
  ]
}

# The aws_eks_cluster.main resource is defined in eks.tf.
# No need to redefine it here.