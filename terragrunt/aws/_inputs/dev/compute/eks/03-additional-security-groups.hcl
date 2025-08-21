locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")

  account_id = local.common_env_vars.locals.dev_account_id
  env        = local.common_env_vars.locals.dev_env
  org_name   = local.common_env_vars.locals.org_name

  security_group_additional_rules = {
    "1" = {
      # NOTE!!! The SG is using source_security_group_id input as a dependency.
      # If you want to update or modify the dependency, refer to the terragrunt.hcl configuration file.
      # Ref: terragrunt/aws/prod/us-east-1/compute/eks/terragrunt.hcl
      description = "Allow to connect to EKS private cluster using openvpn"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
    }
  }
  node_security_group_additional_rules = {}
}