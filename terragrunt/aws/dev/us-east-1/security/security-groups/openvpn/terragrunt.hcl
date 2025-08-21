terraform {
  source = "../../../../../vendor/modules/tf-aws-security-group//modules/openvpn"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../../../network/vpc"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  sg_env_vars     = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/security/security-groups.hcl")
  vpc_env_vars    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/network/vpc.hcl")
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars    = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env        = local.account_vars.locals.environment
  region     = local.region_vars.locals.aws_region
  org_name   = local.common_env_vars.locals.org_name
  account_id = local.account_vars.locals.aws_account_id
}

# ---------------------------------------------------------------------------------------------------------------------
# SUBMODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest/submodules/openvpn
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  create                 = local.sg_env_vars.locals.items.openvpn.create
  name                   = local.sg_env_vars.locals.items.openvpn.name
  description            = local.sg_env_vars.locals.items.openvpn.description
  use_name_prefix        = local.sg_env_vars.locals.items.openvpn.use_name_prefix
  revoke_rules_on_delete = local.sg_env_vars.locals.items.openvpn.revoke_rules_on_delete
  vpc_id                 = dependency.vpc.outputs.vpc_id
  ingress_cidr_blocks    = local.sg_env_vars.locals.items.openvpn.ingress_cidr_blocks
  ingress_rules          = local.sg_env_vars.locals.items.openvpn.ingress_rules
  tags                   = local.sg_env_vars.locals.items.openvpn.tags
}