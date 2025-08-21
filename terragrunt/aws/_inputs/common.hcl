locals {
  # Automatically load AWS user management account-level variables
  global_vars                   = read_terragrunt_config(find_in_parent_folders("global.hcl"))
  dev_account_vars              = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/dev/account.hcl")

  # Extract the variables we need for easy access
  ## Accounts
  dev_account_id              = local.dev_account_vars.locals.aws_account_id
  dev_env                     = local.dev_account_vars.locals.environment

  ## Regions
  default_region       = local.global_vars.locals.default_region

  global_tags  = local.global_vars.locals.tags
  org_name     = local.global_vars.locals.org_name
}