terraform {
  source = "../../../../vendor/modules/tf-aws-key-pair//wrappers"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars   = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  key_pair_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/security/key-pair.hcl")
  region_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars      = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env    = local.account_vars.locals.environment
  region = local.region_vars.locals.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/key-pair/aws/latest
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  defaults = {
    create             = local.key_pair_env_vars.locals.items.defaults.create
    create_private_key = local.key_pair_env_vars.locals.items.defaults.create_private_key
  }

  items = {
    "defaul_ssh_key" = {
      create                = local.key_pair_env_vars.locals.items.defaul_ssh_key.create
      key_name              = local.key_pair_env_vars.locals.items.defaul_ssh_key.key_name
      public_key            = local.key_pair_env_vars.locals.items.defaul_ssh_key.public_key
      private_key_algorithm = local.key_pair_env_vars.locals.items.defaul_ssh_key.private_key_algorithm
      private_key_rsa_bits  = local.key_pair_env_vars.locals.items.defaul_ssh_key.private_key_rsa_bits
      tags                  = local.key_pair_env_vars.locals.items.defaul_ssh_key.tags
    }
  }
}