locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")

  env                         = local.common_env_vars.locals.dev_env
  account_id                  = local.common_env_vars.locals.dev_account_id
  global_tags                 = local.common_env_vars.locals.global_tags
  org_name                    = local.common_env_vars.locals.org_name
  region                      = local.common_env_vars.locals.default_region
  oidc_provider_arn           = "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${local.region}.amazonaws.com/id/PLACEHOLDER"

  #################################################
  # IAM-ASSUMABLE-ROLE SUBMODULE VARIABLES
  # Creates single IAM role which can be assumed by trusted resources.
  # https://registry.terraform.io/modules/terraform-aws-modules/iam/aws/latest/submodules/iam-assumable-role
  #################################################
  assumable_role = {
    "defaults" = {
      admin_role_policy_arn           = "arn:aws:iam::aws:policy/AdministratorAccess"
      allow_self_assume_role          = false
      create_custom_role_trust_policy = false
      create_instance_profile         = false
      create_role                     = true
      custom_role_trust_policy        = "" # (Only valid if create_custom_role_trust_policy = true)
      force_detach_policies           = true
      max_session_duration            = 3600
      mfa_age                         = 86400
      poweruser_role_policy_arn       = "arn:aws:iam::aws:policy/PowerUserAccess"
      readonly_role_policy_arn        = "arn:aws:iam::aws:policy/ReadOnlyAccess"
      role_name_prefix                = null
      role_path                       = "/"
      role_requires_mfa               = false
      role_requires_session_name      = false
      role_session_name               = ["$$${aws:username}"]
      role_sts_externalid             = []
      tags = merge(
        local.global_tags,
        {
          Environment = local.env
        }
      )
      trusted_role_actions = ["sts:AssumeRole", "sts:TagSession"]
    }
    "admin" = {
      create_role                       = true
      attach_admin_policy               = true
      custom_role_policy_arns           = []
      inline_policy_statements          = []
      number_of_custom_role_policy_arns = null
      role_name                         = "DevAdminAccessAssumeRole"
      role_description                  = "Full access assumable role to access opsfleet development account"
      role_permissions_boundary_arn     = ""
      role_requires_mfa                 = true
      trusted_role_arns                 = []
      trusted_role_services             = ["codedeploy.amazonaws.com"]
      tags = merge(
        local.global_tags,
        {
          Environment = local.env
          Role        = "Administrator"
          Permissions = "FullAccess"
          Name        = "DevAdminAccessAssumeRole"
        }
      )
    },
    "poweruser" = {
      create_role                       = true
      attach_poweruser_policy           = true
      custom_role_policy_arns           = []
      inline_policy_statements          = []
      number_of_custom_role_policy_arns = null
      role_name                         = "DevPowerUserAccessAssumeRole"
      role_description                  = "Power users access assumable role to access opsfleet development account"
      role_permissions_boundary_arn     = ""
      role_requires_mfa                 = true
      trusted_role_arns                 = []
      trusted_role_services             = ["codedeploy.amazonaws.com"]
      tags = merge(
        local.global_tags,
        {
          Environment = local.env
          Role        = "Developer"
          Permissions = "PowerUser"
          Name        = "DevPowerUserAccessAssumeRole"
        }
      )
    },
    "readonly" = {
      create_role                       = true
      attach_readonly_policy            = true
      custom_role_policy_arns           = []
      inline_policy_statements          = []
      number_of_custom_role_policy_arns = null
      role_name                         = "DevReadOnlyAccessAssumeRole"
      role_description                  = "ReadOnly access assumable role to access opsfleet development account"
      role_permissions_boundary_arn     = ""
      role_requires_mfa                 = true
      trusted_role_arns                 = []
      trusted_role_services             = ["codedeploy.amazonaws.com"]
      tags = merge(
        local.global_tags,
        {
          Environment = local.env
          Role        = "ReadOnly"
          Name        = "DevReadOnlyAccessAssumeRole"
        }
      )
    },
    "kube_admin" = {
      create_role                         = true
      custom_role_policy_arns             = []
      inline_policy_statements            = []
      number_of_custom_role_policy_arns   = null
      role_name                           = "DevKubeAdmin"
      role_description                    = "EKS cluster admin access assumable role"
      role_permissions_boundary_arn       = ""
      role_requires_mfa                   = true
      trusted_role_arns                   = []
      trusted_role_services               = ["codedeploy.amazonaws.com"]
      tags = merge(
        local.global_tags,
        {
          Environment = local.env
          Name        = "DevKubeAdmin"
          Permissions = "EKSAdminAccess"
        }
      )
    },
    "kube_readonly" = {
      create_role                         = true
      custom_role_policy_arns             = []
      inline_policy_statements            = []
      number_of_custom_role_policy_arns   = null
      role_name                           = "DevKubeReadOnly"
      role_description                    = "EKS cluster readonly access assumable role"
      role_permissions_boundary_arn       = ""
      role_requires_mfa                   = true
      trusted_role_arns                   = []
      trusted_role_services               = ["codedeploy.amazonaws.com"]
      tags = merge(
        local.global_tags,
        {
          Environment = local.env
          Name        = "DevKubeReadOnly"
          Permissions = "EKSReadOnly"
        }
      )
    }
  }
}