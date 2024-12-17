# Source of the module from _modules
 terraform {
   source = "${get_parent_terragrunt_dir()}../../../_modules/local/data/"
 }

# Locals from env.hcl
 locals {
   # Automatically load environment-level variables
   environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
   
   vpc = local.environment_vars.locals.vpc
 }

# Local Data module inputs
 inputs = {
    vpc_name = local.vpc.name
 }
