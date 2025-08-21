# Set account-wide variables. These are automatically pulled in to configure the remote state bucket in the root
# terragrunt.hcl configuration.
locals {
  account_name   = "dev"
  aws_account_id = get_env("AWS_ACCOUNT_ID_DEV")
  aws_profile    = "seedify-dev"
  role_to_assume = get_env("IAM_ASSUME_ROLE", "infraAsCode")
  environment    = "dev"
}