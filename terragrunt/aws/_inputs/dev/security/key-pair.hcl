locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  org_name        = local.common_env_vars.locals.org_name
  dev_account_id  = local.common_env_vars.locals.dev_account_id
  env             = local.common_env_vars.locals.dev_env
  global_tags     = local.common_env_vars.locals.global_tags


  #################################################
  # KEY PAIR MODULE VARIABLES
  # Terraform module to create AWS EC2 key pair resources
  # https://registry.terraform.io/modules/terraform-aws-modules/key-pair/aws/latest
  #################################################
  items = {
    "defaults" = {
      create             = true
      create_private_key = true
    },
    "defaul_ssh_key" = {
      create                = true
      key_name              = "default-ssh-key-${local.env}"
      public_key            = ""
      private_key_algorithm = "RSA"
      private_key_rsa_bits  = 4096
      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Name        = "default-ssh-key-${local.env}"
        }
      )
    }
  }
}