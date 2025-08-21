terraform {
  source = "../../../../vendor/modules/tf-aws-kms//wrappers"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependencies {
  paths = [
    "../../../_global/iam/roles/assumable-roles"
  ]
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  kms_env_vars    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/security/kms.hcl")
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars    = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env        = local.account_vars.locals.environment
  region     = local.region_vars.locals.aws_region
  account_id = local.account_vars.locals.aws_account_id
  org_name   = local.common_env_vars.locals.org_name
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/latest
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  defaults = {
    create                  = local.kms_env_vars.locals.items.defaults.create
    is_enabled              = local.kms_env_vars.locals.items.defaults.is_enabled
    enable_default_policy   = local.kms_env_vars.locals.items.defaults.enable_default_policy
    multi_region            = local.kms_env_vars.locals.items.defaults.multi_region
    deletion_window_in_days = local.kms_env_vars.locals.items.defaults.deletion_window_in_days
    rotation_period_in_days = local.kms_env_vars.locals.items.defaults.rotation_period_in_days
  }
  items = {
    "ec2_ebs" = {
      create                   = local.kms_env_vars.locals.items.ec2_ebs.create
      is_enabled               = local.kms_env_vars.locals.items.ec2_ebs.is_enabled
      aliases                  = local.kms_env_vars.locals.items.ec2_ebs.aliases
      description              = local.kms_env_vars.locals.items.ec2_ebs.description
      enable_key_rotation      = local.kms_env_vars.locals.items.ec2_ebs.enable_key_rotation
      key_usage                = local.kms_env_vars.locals.items.ec2_ebs.key_usage
      customer_master_key_spec = local.kms_env_vars.locals.items.ec2_ebs.customer_master_key_spec
      policy                   = local.kms_env_vars.locals.items.ec2_ebs.policy
      tags                     = local.kms_env_vars.locals.items.ec2_ebs.tags
    },
    "sqs" = {
      create                   = local.kms_env_vars.locals.items.sqs.create
      is_enabled               = local.kms_env_vars.locals.items.sqs.is_enabled
      aliases                  = local.kms_env_vars.locals.items.sqs.aliases
      description              = local.kms_env_vars.locals.items.sqs.description
      enable_key_rotation      = local.kms_env_vars.locals.items.sqs.enable_key_rotation
      key_usage                = local.kms_env_vars.locals.items.sqs.key_usage
      customer_master_key_spec = local.kms_env_vars.locals.items.sqs.customer_master_key_spec
      policy                   = local.kms_env_vars.locals.items.sqs.policy
      tags                     = local.kms_env_vars.locals.items.sqs.tags
    },
    "cloudwatch_logs" = {
      create                   = local.kms_env_vars.locals.items.cloudwatch_logs.create
      is_enabled               = local.kms_env_vars.locals.items.cloudwatch_logs.is_enabled
      aliases                  = local.kms_env_vars.locals.items.cloudwatch_logs.aliases
      description              = local.kms_env_vars.locals.items.cloudwatch_logs.description
      enable_key_rotation      = local.kms_env_vars.locals.items.cloudwatch_logs.enable_key_rotation
      key_usage                = local.kms_env_vars.locals.items.cloudwatch_logs.key_usage
      customer_master_key_spec = local.kms_env_vars.locals.items.cloudwatch_logs.customer_master_key_spec
      policy                   = local.kms_env_vars.locals.items.cloudwatch_logs.policy
      tags                     = local.kms_env_vars.locals.items.cloudwatch_logs.tags
    }
  }
}