################################################################################
# EKS Module
################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.35.0"

  cluster_name    = local.name
  cluster_version = var.eks_version

  enable_cluster_creator_admin_permissions = true
  cluster_endpoint_public_access           = true

  cluster_addons = {
    coredns = {
      configuration_values = jsonencode({
        replicaCount = 1
      })
    }
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
  }

  vpc_id                   = data.terraform_remote_state.vpc.outputs.vpc_id
  subnet_ids               = data.terraform_remote_state.vpc.outputs.private_subnets
  control_plane_subnet_ids = data.terraform_remote_state.vpc.outputs.control_plane_subnet_ids

  eks_managed_node_groups = {
    eks-base = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.small", "t3a.small"]

      min_size      = 1
      max_size      = 1
      desired_size  = 1
      capacity_type = "SPOT"
      network_interfaces = [{
        delete_on_termination = true
      }]
    }
  }
  
  node_security_group_additional_rules = {
    allow-all-80-traffic-from-loadbalancers = {
      cidr_blocks = [for s in data.aws_subnet.elb_subnets : s.cidr_block]
      description = "Allow all traffic from load balancers"
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      type        = "ingress"
    }
    hybrid-all = {
      cidr_blocks = ["192.168.100.0/23"]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  cluster_security_group_additional_rules = {
    hybrid-all = {
      cidr_blocks = ["192.168.100.0/23"]
      description = "Allow all traffic from remote node/pod network"
      from_port   = 0
      to_port     = 0
      protocol    = "all"
      type        = "ingress"
    }
  }

  cluster_remote_network_config = {
    remote_node_networks = {
      cidrs = ["192.168.100.0/24"]
    }
    remote_pod_networks = {
      cidrs = ["192.168.101.0/24"]
    }
  }
  
  access_entries = {
    hybrid-node-role = {
      principal_arn = module.eks_hybrid_node_role.arn
      type          = "HYBRID_LINUX"
    }
  }


  node_security_group_tags = merge(local.tags, {
    "karpenter.sh/discovery" = local.name
  })

  tags = local.tags
}

################################################################################
# Hybrid nodes Support
################################################################################
module "eks_hybrid_node_role" {
  source = "terraform-aws-modules/eks/aws//modules/hybrid-node-role"
  version = "20.35.0"

  name = "hybrid"

  tags = local.tags
}


resource "aws_ssm_activation" "this" {
  name               = "hybrid-node"
  iam_role           = module.eks_hybrid_node_role.name
  registration_limit = 10

  tags = local.tags
}

resource "local_file" "nodeConfig" {
  content  = <<-EOT
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${module.eks.cluster_name}
        region: ${local.region}
      hybrid:
        ssm:
          activationId: ${aws_ssm_activation.this.id}
          activationCode: ${aws_ssm_activation.this.activation_code} 
  EOT
  filename = "nodeConfig.yaml"
}