# Include the root `terragrunt.hcl`
 include "root" {
   path = find_in_parent_folders()
 }

# Source of the module from _env
 include "env" {
   path = "${get_terragrunt_dir()}/../../_env/karpenter.hcl"
 }
