locals {
  common_env_vars  = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  account_id       = local.common_env_vars.locals.dev_account_id
  org_name         = local.common_env_vars.locals.org_name
  env              = local.common_env_vars.locals.dev_env
  default_region   = local.common_env_vars.locals.default_region

  ##################################################################################################
  # AWS SECURITY GROUPS VARIABLES
  # Terraform module to create AWS Security Group resources
  # Ref: https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest
  ##################################################################################################

  items = {
    "openvpn" = {
      create                 = true
      name                   = "openvpn-sg"
      description            = "Enable OpenVPN connection to access OpsFleet Private Network"
      use_name_prefix        = true
      revoke_rules_on_delete = true
      ingress_cidr_blocks    = ["0.0.0.0/0"] # Allow to connect to OpenVPN from anywhere
      # Allow EC2 Instance Connect (SSH over 22/TCP) from AWS EC2 Instance Connect service ranges or your office IPs
      ingress_rules          = ["ssh-tcp"]

      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Name        = "openvpn-sg"
          UsedBy      = "OpenVPN"
        }
      )
    }
  }
}