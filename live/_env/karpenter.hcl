# Source of the module from _modules
 terraform {
   source = "${get_parent_terragrunt_dir()}../../../_modules/remote/eks/modules/karpenter/"
 }

# Locals from env.hcl
 locals {
   # Automatically load environment-level variables
   environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
   
   env_name      = local.environment_vars.locals.environment
   general_name  = local.environment_vars.locals.general_name
   karpenter     = local.environment_vars.locals.karpenter
   mock_commands = local.environment_vars.locals.mock_commands
 }

# Generate a K8S provider block
  generate "provider" {
    path      = "versions.tf"
    if_exists = "overwrite"
    contents  = <<EOF
  terraform {
    required_providers {
      kubectl = {
        source  = "gavinbunney/kubectl"
      }
    }
  }

  provider "kubernetes" {
    config_path    = "${pathexpand("~/${local.env_name}-${local.general_name}")}"
    config_context = "${local.env_name}-${local.general_name}"
  }

  provider "kubectl" {
    config_path    = "${pathexpand("~/${local.env_name}-${local.general_name}")}"
    config_context = "${local.env_name}-${local.general_name}"
  }

  provider "helm" {
   kubernetes {
     config_path    = "${pathexpand("~/${local.env_name}-${local.general_name}")}"
     config_context = "${local.env_name}-${local.general_name}"
   }
  }
  EOF
  }
# Generate Karpenter helm_release.
  generate "helm_release" {
    path      = "helm_release.tf"
    if_exists = "overwrite"
    contents  = <<EOF
  resource "helm_release" "karpenter" {
    namespace           = "kube-system"
    name                = "karpenter"
    repository          = "oci://public.ecr.aws/karpenter"
    chart               = "karpenter"
    version             = "1.1.0"
    wait                = false

    values = [templatefile("templates/karpenter-values.yaml", {
       cluster_name     = "${dependency.eks.outputs.cluster_name}"
       cluster_endpoint = "${dependency.eks.outputs.cluster_endpoint}"
       queue_name       = aws_sqs_queue.this[0].name
       })]
    }
  EOF
  }

# Generate Karpenter node_class.
  generate "karpenter_node_class" {
    path      = "karpenter_node_class.tf"
    if_exists = "overwrite"
    contents  = <<EOF
  resource "kubectl_manifest" "karpenter_node_class" {
    depends_on = [helm_release.karpenter]
    yaml_body = <<YAML
      apiVersion: karpenter.k8s.aws/v1
      kind: EC2NodeClass
      metadata:
        name: default
      spec:
        amiFamily: AL2023
        role: aws_iam_role.node[0].name
        subnetSelectorTerms:
          - tags:
              karpenter.sh/discovery: ${dependency.eks.outputs.cluster_name}
        securityGroupSelectorTerms:
          - tags:
              karpenter.sh/discovery: ${dependency.eks.outputs.cluster_name}
        tags:
          karpenter.sh/discovery: ${dependency.eks.outputs.cluster_name}
     YAML
    }
  EOF
  }

# Generate Karpenter node_pool.
  generate "karpenter_node_pool" {
    path      = "karpenter_node_pool.tf"
    if_exists = "overwrite"
    contents  = <<EOF
  resource "kubectl_manifest" "karpenter_node_pool" {
    depends_on = [kubectl_manifest.karpenter_node_class]
    yaml_body = <<YAML
      apiVersion: karpenter.sh/v1
      kind: NodePool
      metadata:
        name: default
      spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64", "arm64"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand", "spot"]
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32"]
      limits:
        cpu: 1000
        memory: s1000Gi
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
     YAML
    }
  EOF
  }

# Dependencies
 dependency "eks" {
   config_path = "../eks"

   # Configure mock outputs for the `plan` command that are returned when there are no outputs available (e.g the module hasn't been applied yet.)
    mock_outputs_allowed_terraform_commands = local.mock_commands
    mock_outputs = {
      cluster_name     = "mock_name"
      cluster_endpoint = "mock_endpoint"
    }
 }

# Inputs for Karpenter module
 inputs = merge(
    local.karpenter
  )
