resource "helm_release" "aws-load-balancer-controller" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"
  version    = "1.12.0"

  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = module.eks_loadbalancer_iam.iam_role_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks_loadbalancer_iam.iam_role_arn
  }
  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "replicaCount"
    value = "1"
  }
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.vpc.outputs.vpc_id
  }
}

module "eks_loadbalancer_iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.54.0"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:load-balancer-controller"]
    }
  }
}