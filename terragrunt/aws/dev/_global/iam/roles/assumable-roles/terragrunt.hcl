terraform {
  source = "../../../../../vendor/modules/tf-aws-iam//wrappers/iam-assumable-role"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  iam_env_vars    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/iam/roles.hcl")
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars    = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env        = local.account_vars.locals.environment
  region     = local.region_vars.locals.aws_region
  org_name   = local.common_env_vars.locals.org_name
  account_id = local.common_env_vars.locals.dev_account_id

}
# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest/submodules/iam-assumable-role
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  defaults = {
    admin_role_policy_arn           = local.iam_env_vars.locals.assumable_role.defaults.admin_role_policy_arn
    allow_self_assume_role          = local.iam_env_vars.locals.assumable_role.defaults.allow_self_assume_role
    create_custom_role_trust_policy = local.iam_env_vars.locals.assumable_role.defaults.create_custom_role_trust_policy
    create_instance_profile         = local.iam_env_vars.locals.assumable_role.defaults.create_instance_profile
    create_role                     = local.iam_env_vars.locals.assumable_role.defaults.create_role
    custom_role_trust_policy        = local.iam_env_vars.locals.assumable_role.defaults.custom_role_trust_policy
    force_detach_policies           = local.iam_env_vars.locals.assumable_role.defaults.force_detach_policies
    max_session_duration            = local.iam_env_vars.locals.assumable_role.defaults.max_session_duration
    mfa_age                         = local.iam_env_vars.locals.assumable_role.defaults.mfa_age
    poweruser_role_policy_arn       = local.iam_env_vars.locals.assumable_role.defaults.poweruser_role_policy_arn
    readonly_role_policy_arn        = local.iam_env_vars.locals.assumable_role.defaults.readonly_role_policy_arn
    role_name_prefix                = local.iam_env_vars.locals.assumable_role.defaults.role_name_prefix
    role_path                       = local.iam_env_vars.locals.assumable_role.defaults.role_path
    role_requires_mfa               = local.iam_env_vars.locals.assumable_role.defaults.role_requires_mfa
    role_requires_session_name      = local.iam_env_vars.locals.assumable_role.defaults.role_requires_session_name
    role_session_name               = local.iam_env_vars.locals.assumable_role.defaults.role_session_name
    role_sts_externalid             = local.iam_env_vars.locals.assumable_role.defaults.role_sts_externalid
    tags                            = local.iam_env_vars.locals.assumable_role.defaults.tags
    trusted_role_actions            = local.iam_env_vars.locals.assumable_role.defaults.trusted_role_actions
  }
  items = {
    "admin" = {
      attach_admin_policy               = local.iam_env_vars.locals.assumable_role.admin.attach_admin_policy
      create_role                       = local.iam_env_vars.locals.assumable_role.admin.create_role
      custom_role_policy_arns           = local.iam_env_vars.locals.assumable_role.admin.custom_role_policy_arns
      inline_policy_statements          = local.iam_env_vars.locals.assumable_role.admin.inline_policy_statements
      number_of_custom_role_policy_arns = local.iam_env_vars.locals.assumable_role.admin.number_of_custom_role_policy_arns
      role_name                         = local.iam_env_vars.locals.assumable_role.admin.role_name
      role_description                  = local.iam_env_vars.locals.assumable_role.admin.role_description
      role_permissions_boundary_arn     = local.iam_env_vars.locals.assumable_role.admin.role_permissions_boundary_arn
      role_requires_mfa                 = local.iam_env_vars.locals.assumable_role.admin.role_requires_mfa
      trusted_role_arns                 = local.iam_env_vars.locals.assumable_role.admin.trusted_role_arns
      trusted_role_services             = local.iam_env_vars.locals.assumable_role.admin.trusted_role_services
      tags                              = local.iam_env_vars.locals.assumable_role.admin.tags
    },
    "poweruser" = {
      attach_poweruser_policy           = local.iam_env_vars.locals.assumable_role.poweruser.attach_poweruser_policy
      create_role                       = local.iam_env_vars.locals.assumable_role.poweruser.create_role
      custom_role_policy_arns           = local.iam_env_vars.locals.assumable_role.poweruser.custom_role_policy_arns
      inline_policy_statements          = local.iam_env_vars.locals.assumable_role.poweruser.inline_policy_statements
      number_of_custom_role_policy_arns = local.iam_env_vars.locals.assumable_role.poweruser.number_of_custom_role_policy_arns
      role_name                         = local.iam_env_vars.locals.assumable_role.poweruser.role_name
      role_description                  = local.iam_env_vars.locals.assumable_role.poweruser.role_description
      role_permissions_boundary_arn     = local.iam_env_vars.locals.assumable_role.poweruser.role_permissions_boundary_arn
      role_requires_mfa                 = local.iam_env_vars.locals.assumable_role.poweruser.role_requires_mfa
      trusted_role_arns                 = local.iam_env_vars.locals.assumable_role.poweruser.trusted_role_arns
      trusted_role_services             = local.iam_env_vars.locals.assumable_role.poweruser.trusted_role_services
      tags                              = local.iam_env_vars.locals.assumable_role.poweruser.tags
    },
    "readonly" = {
      attach_readonly_policy            = local.iam_env_vars.locals.assumable_role.readonly.attach_readonly_policy
      create_role                       = local.iam_env_vars.locals.assumable_role.readonly.create_role
      custom_role_policy_arns           = local.iam_env_vars.locals.assumable_role.readonly.custom_role_policy_arns
      inline_policy_statements          = local.iam_env_vars.locals.assumable_role.readonly.inline_policy_statements
      number_of_custom_role_policy_arns = local.iam_env_vars.locals.assumable_role.readonly.number_of_custom_role_policy_arns
      role_name                         = local.iam_env_vars.locals.assumable_role.readonly.role_name
      role_description                  = local.iam_env_vars.locals.assumable_role.readonly.role_description
      role_permissions_boundary_arn     = local.iam_env_vars.locals.assumable_role.readonly.role_permissions_boundary_arn
      role_requires_mfa                 = local.iam_env_vars.locals.assumable_role.readonly.role_requires_mfa
      trusted_role_arns                 = local.iam_env_vars.locals.assumable_role.readonly.trusted_role_arns
      trusted_role_services             = local.iam_env_vars.locals.assumable_role.readonly.trusted_role_services
      tags                              = local.iam_env_vars.locals.assumable_role.readonly.tags
    },
    "kube_admin" = {
      create_role                       = local.iam_env_vars.locals.assumable_role.kube_admin.create_role
      custom_role_policy_arns           = local.iam_env_vars.locals.assumable_role.kube_admin.custom_role_policy_arns
      inline_policy_statements          = local.iam_env_vars.locals.assumable_role.kube_admin.inline_policy_statements
      number_of_custom_role_policy_arns = local.iam_env_vars.locals.assumable_role.kube_admin.number_of_custom_role_policy_arns
      role_name                         = local.iam_env_vars.locals.assumable_role.kube_admin.role_name
      role_description                  = local.iam_env_vars.locals.assumable_role.kube_admin.role_description
      role_permissions_boundary_arn     = local.iam_env_vars.locals.assumable_role.kube_admin.role_permissions_boundary_arn
      role_requires_mfa                 = local.iam_env_vars.locals.assumable_role.kube_admin.role_requires_mfa
      trusted_role_arns                 = local.iam_env_vars.locals.assumable_role.kube_admin.trusted_role_arns
      trusted_role_services             = local.iam_env_vars.locals.assumable_role.kube_admin.trusted_role_services
      tags                              = local.iam_env_vars.locals.assumable_role.kube_admin.tags
    },
    "kube_readonly" = {
      create_role                       = local.iam_env_vars.locals.assumable_role.kube_readonly.create_role
      custom_role_policy_arns           = local.iam_env_vars.locals.assumable_role.kube_readonly.custom_role_policy_arns
      inline_policy_statements          = local.iam_env_vars.locals.assumable_role.kube_readonly.inline_policy_statements
      number_of_custom_role_policy_arns = local.iam_env_vars.locals.assumable_role.kube_readonly.number_of_custom_role_policy_arns
      role_name                         = local.iam_env_vars.locals.assumable_role.kube_readonly.role_name
      role_description                  = local.iam_env_vars.locals.assumable_role.kube_readonly.role_description
      role_permissions_boundary_arn     = local.iam_env_vars.locals.assumable_role.kube_readonly.role_permissions_boundary_arn
      role_requires_mfa                 = local.iam_env_vars.locals.assumable_role.kube_readonly.role_requires_mfa
      trusted_role_arns                 = local.iam_env_vars.locals.assumable_role.kube_readonly.trusted_role_arns
      trusted_role_services             = local.iam_env_vars.locals.assumable_role.kube_readonly.trusted_role_services
      tags                              = local.iam_env_vars.locals.assumable_role.kube_readonly.tags
    }
  }
}