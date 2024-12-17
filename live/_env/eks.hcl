# Source of the module from _modules
 terraform {
   source = "${get_parent_terragrunt_dir()}../../../_modules/remote/eks/"
 
   after_hook "kubeconfig" {
      commands = ["apply"]
      execute  = ["bash", "-c", "aws eks update-kubeconfig --name ${local.env_name}-${local.general_name} --region ${local.aws_region} --kubeconfig  ${pathexpand("~/${local.env_name}-${local.general_name}")} 2>/dev/null --alias ${local.env_name}-${local.general_name}"]
   }
 }

# Locals from env.hcl
 locals {
   # Automatically load environment-level variables
   environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
   
   aws_region    = local.environment_vars.locals.aws_region
   env_name      = local.environment_vars.locals.environment
   eks           = local.environment_vars.locals.eks
   general_name  = local.environment_vars.locals.general_name
   mock_commands = local.environment_vars.locals.mock_commands
   vpc           = local.environment_vars.locals.vpc
 }

# Generate an K8S provider block
  generate "provider" {
    path      = "kubernetes.tf"
    if_exists = "overwrite"
    contents  = <<EOF
  provider "kubernetes" {
    host                   = aws_eks_cluster.this[0].endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this[0].certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this[0].id]
    }
  }
  EOF
  }

# Dependencies
 dependency "data" {
   config_path = "../data"

   # Configure mock outputs for the `plan` command that are returned when there are no outputs available (e.g the module hasn't been applied yet.)
   mock_outputs_allowed_terraform_commands = local.mock_commands
   mock_outputs = {
     vpc_id             = "mock_id"
     public_subnet_ids  = ["mock_id", "mock_id"]
     private_subnet_ids = ["mock_id", "mock_id"]
   }
 }

# AWS EKS module inputs
 inputs = merge(
   local.eks,
   {
     vpc_id     = dependency.data.outputs.vpc_id
     subnet_ids = dependency.data.outputs.private_subnet_ids
   }
 )
