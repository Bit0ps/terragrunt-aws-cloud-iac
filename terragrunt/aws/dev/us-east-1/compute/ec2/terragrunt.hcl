terraform {
  source = "../../../../vendor/modules/tf-aws-ec2//wrappers"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "openvpn_sg" {
  config_path = "../../security/security-groups/openvpn"
  mock_outputs = {
    security_group_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "vpc" {
  config_path = "../../network/vpc"
  mock_outputs = {
    public_subnets = ["subnet-00000000000000000"]
    vpc_cidr_block = "10.0.0.0/16"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  ec2_env_vars    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/ec2.hcl")
  vpc_env_vars    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/network/vpc.hcl")
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
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  defaults = {
    ami                                  = local.ec2_env_vars.locals.defaults.ami
    ami_ssm_parameter                    = local.ec2_env_vars.locals.defaults.ami_ssm_parameter
    associate_public_ip_address          = local.ec2_env_vars.locals.defaults.associate_public_ip_address
    availability_zone                    = local.ec2_env_vars.locals.defaults.availability_zone
    capacity_reservation_specification   = local.ec2_env_vars.locals.defaults.capacity_reservation_specification
    cpu_credits                          = local.ec2_env_vars.locals.defaults.cpu_credits
    cpu_options                          = local.ec2_env_vars.locals.defaults.cpu_options
    cpu_threads_per_core                 = local.ec2_env_vars.locals.defaults.cpu_threads_per_core
    create                               = local.ec2_env_vars.locals.defaults.create
    create_eip                           = local.ec2_env_vars.locals.defaults.create_eip
    create_iam_instance_profile          = local.ec2_env_vars.locals.defaults.create_iam_instance_profile
    create_spot_instance                 = local.ec2_env_vars.locals.defaults.create_spot_instance
    disable_api_stop                     = local.ec2_env_vars.locals.defaults.disable_api_stop
    disable_api_termination              = local.ec2_env_vars.locals.defaults.disable_api_termination
    ebs_optimized                        = local.ec2_env_vars.locals.defaults.ebs_optimized
    eip_domain                           = local.ec2_env_vars.locals.defaults.eip_domain
    eip_tags                             = local.ec2_env_vars.locals.defaults.eip_tags
    enable_volume_tags                   = local.ec2_env_vars.locals.defaults.enable_volume_tags
    enclave_options_enabled              = local.ec2_env_vars.locals.defaults.enclave_options_enabled
    ephemeral_block_device               = local.ec2_env_vars.locals.defaults.ephemeral_block_device
    get_password_data                    = local.ec2_env_vars.locals.defaults.get_password_data
    hibernation                          = local.ec2_env_vars.locals.defaults.hibernation
    host_id                              = local.ec2_env_vars.locals.defaults.host_id
    iam_role_use_name_prefix             = local.ec2_env_vars.locals.defaults.iam_role_use_name_prefix
    ignore_ami_changes                   = local.ec2_env_vars.locals.defaults.ignore_ami_changes
    instance_initiated_shutdown_behavior = local.ec2_env_vars.locals.defaults.instance_initiated_shutdown_behavior
    instance_type                        = local.ec2_env_vars.locals.defaults.instance_type
    ipv6_address_count                   = local.ec2_env_vars.locals.defaults.ipv6_address_count
    ipv6_addresses                       = local.ec2_env_vars.locals.defaults.ipv6_addresses
    key_name                             = local.ec2_env_vars.locals.defaults.key_name
    launch_template                      = local.ec2_env_vars.locals.defaults.launch_template
    maintenance_options                  = local.ec2_env_vars.locals.defaults.maintenance_options
    metadata_options                     = local.ec2_env_vars.locals.defaults.metadata_options
    monitoring                           = local.ec2_env_vars.locals.defaults.monitoring
    network_interface                    = local.ec2_env_vars.locals.defaults.network_interface
    placement_group                      = local.ec2_env_vars.locals.defaults.placement_group
    putin_khuylo                         = local.ec2_env_vars.locals.defaults.putin_khuylo
    secondary_private_ips                = local.ec2_env_vars.locals.defaults.secondary_private_ips
    source_dest_check                    = local.ec2_env_vars.locals.defaults.source_dest_check
    spot_block_duration_minutes          = local.ec2_env_vars.locals.defaults.spot_block_duration_minutes
    spot_instance_interruption_behavior  = local.ec2_env_vars.locals.defaults.spot_instance_interruption_behavior
    spot_launch_group                    = local.ec2_env_vars.locals.defaults.spot_launch_group
    spot_price                           = local.ec2_env_vars.locals.defaults.spot_price
    spot_type                            = local.ec2_env_vars.locals.defaults.spot_type
    spot_valid_from                      = local.ec2_env_vars.locals.defaults.spot_valid_from
    spot_valid_until                     = local.ec2_env_vars.locals.defaults.spot_valid_until
    spot_wait_for_fulfillment            = local.ec2_env_vars.locals.defaults.spot_wait_for_fulfillment
    subnet_id                            = dependency.vpc.outputs.public_subnets[0]
    tenancy                              = local.ec2_env_vars.locals.defaults.tenancy
    timeouts                             = local.ec2_env_vars.locals.defaults.timeouts
    user_data_replace_on_change          = local.ec2_env_vars.locals.defaults.user_data_replace_on_change
    volume_tags                          = local.ec2_env_vars.locals.defaults.volume_tags
    tags                                 = local.ec2_env_vars.locals.defaults.tags
  }
  items = {
    "openvpn" = {
      create                      = local.ec2_env_vars.locals.items.openvpn.create
      create_eip                  = local.ec2_env_vars.locals.items.openvpn.create_eip
      associate_public_ip_address = local.ec2_env_vars.locals.items.openvpn.associate_public_ip_address
      name                        = local.ec2_env_vars.locals.items.openvpn.name
      instance_type               = local.ec2_env_vars.locals.items.openvpn.instance_type
      user_data_replace_on_change = local.ec2_env_vars.locals.items.openvpn.user_data_replace_on_change
      root_block_device           = local.ec2_env_vars.locals.items.openvpn.root_block_device

      ### EC2 INSTANCE IAM ROLE ###
      iam_role_description          = local.ec2_env_vars.locals.items.openvpn.iam_role_description
      iam_role_name                 = local.ec2_env_vars.locals.items.openvpn.iam_role_name
      iam_role_path                 = local.ec2_env_vars.locals.items.openvpn.iam_role_path
      iam_role_permissions_boundary = local.ec2_env_vars.locals.items.openvpn.iam_role_permissions_boundary
      iam_role_policies             = local.ec2_env_vars.locals.items.openvpn.iam_role_policies

      vpc_security_group_ids = [dependency.openvpn_sg.outputs.security_group_id]

      user_data_base64 = base64encode(
        templatefile("./userdata/openvpn.sh", {
          GATEWAY_IP    = cidrhost(dependency.vpc.outputs.vpc_cidr_block, 2),
          ROUTE_IP      = cidrhost(dependency.vpc.outputs.vpc_cidr_block, 0),
          ROUTE_NETMASK = cidrnetmask(dependency.vpc.outputs.vpc_cidr_block)
        })
      )

      # Tags
      iam_role_tags = local.ec2_env_vars.locals.items.openvpn.iam_role_tags
      eip_tags      = local.ec2_env_vars.locals.items.openvpn.eip_tags
      volume_tags   = local.ec2_env_vars.locals.items.openvpn.volume_tags
      tags          = local.ec2_env_vars.locals.items.openvpn.tags
    }
  }
}
