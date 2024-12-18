# Set common variables for the environment. This is automatically pulled in in the root terragrunt.hcl configuration to
# feed forward to the child modules.
locals {
# Global common variables
  account_name   = "dev"
  aws_account_id = "123456789012"
  aws_region     = "us-east-1"
  azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
  environment    = "dev"
  general_name   = "eks-karpenter"
  mock_commands  = ["init", "plan", "validate"]
  common_tags    = {
    Environment = local.environment
    ManagedBy   = "Terraform"
  }

# Global VPC variables
  vpc = {
   name = "vpc-dev"
  }

# Global EKS variables
  eks = {
   cluster_name                             = "${local.environment}-${local.general_name}"
   cluster_version                          = "1.31"
   enable_cluster_creator_admin_permissions = true
   enable_irsa                              = true
   cloudwatch_log_group_retention_in_days   = 30
   iam_role_name                            = "${local.environment}-${local.general_name}"
   tags                                     = local.common_tags
   cluster_endpoint_public_access           = true
   cluster_endpoint_public_access_cidrs     = ["yourPublicIp"] # For demo purposes. Replace with your Public IP.
   cluster_addons = {
     coredns = {
       resolve_conflicts = "OVERWRITE"
       most_recent       = true # To ensure access to the latest settings provided
     }
     eks-pod-identity-agent = {
       resolve_conflicts = "OVERWRITE"
       most_recent       = true # To ensure access to the latest settings provided
     }
     kube-proxy = {
       resolve_conflicts = "OVERWRITE"
       most_recent       = true # To ensure access to the latest settings provided
     }
     vpc-cni = {
      # Specify the VPC CNI addon should be deployed before compute to ensure
      # the addon is configured before data plane compute resources are created
      resolve_conflicts    = "OVERWRITE"
      before_compute       = true
      most_recent          = true # To ensure access to the latest settings provided
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
     }
   }

   eks_managed_node_groups = {
     karpenter = {
       ami_type       = "AL2023_x86_64_STANDARD"
       instance_types = ["m5.large"]
       min_size       = 1
       max_size       = 3
       desired_size   = 1
       labels = {
         role = "karpenter"
       }
       tags = {
         role = "karpenter"
       }
     }
   }

   node_security_group_additional_rules = {
     ingress_self_all = {
       from_port = 0
       to_port   = 0
       protocol  = "-1"
       type      = "ingress"
       self      = true
     }
     ingress_cluster_all = {
       from_port                     = 0
       to_port                       = 0
       protocol                      = "-1"
       type                          = "ingress"
       source_cluster_security_group = true
     }
     egress_all = {
       from_port        = 0
       to_port          = 0
       protocol         = "-1"
       type             = "egress"
       cidr_blocks      = ["0.0.0.0/0"]
       ipv6_cidr_blocks = ["::/0"]
     }
   }

   node_security_group_tags = merge(local.common_tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = "${local.environment}-${local.general_name}"
   })
  }

# Global Karpenter variables
  karpenter = {
   cluster_name                    = "${local.environment}-${local.general_name}"
   enable_v1_permissions           = true
   enable_pod_identity             = true
   create_pod_identity_association = true
   tags                            = local.common_tags
   # Used to attach additional IAM policies to the Karpenter node IAM role
   node_iam_role_additional_policies = {
     AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
   }
  }
}
