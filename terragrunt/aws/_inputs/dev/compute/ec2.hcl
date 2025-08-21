locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  account_id      = local.common_env_vars.locals.dev_account_id
  env             = local.common_env_vars.locals.dev_env
  default_region  = local.common_env_vars.locals.default_region

  #################################################
  # AWS EC2 MODULE VARIABLES
  # Terraform module to create AWS EC2 instance(s) resources
  # https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest
  #################################################
  defaults = {
    ami                                  = null
    ami_ssm_parameter                    = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
    associate_public_ip_address          = false
    availability_zone                    = "${local.default_region}a"
    capacity_reservation_specification   = null
    cpu_credits                          = null
    cpu_options                          = null
    cpu_threads_per_core                 = null
    create                               = true
    create_eip                           = false
    create_iam_instance_profile          = false
    create_spot_instance                 = false
    disable_api_stop                     = false
    disable_api_termination              = false
    ebs_optimized                        = true
    eip_domain                           = "vpc"
    enable_volume_tags                   = true
    enclave_options_enabled              = false
    ephemeral_block_device               = null
    get_password_data                    = false
    hibernation                          = true
    host_id                              = null
    iam_role_use_name_prefix             = true
    ignore_ami_changes                   = true
    instance_initiated_shutdown_behavior = null
    instance_type                        = "t3.medium"
    ipv6_address_count                   = null
    ipv6_addresses                       = null
    key_name                             = "default-ssh-key-${local.env}"
    launch_template                      = null
    maintenance_options                  = null
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 1
      instance_metadata_tags      = "disabled"
    }
    monitoring                          = false
    network_interface                   = null
    placement_group                     = null
    putin_khuylo                        = true
    secondary_private_ips               = null
    source_dest_check                   = null
    spot_block_duration_minutes         = null
    spot_instance_interruption_behavior = null
    spot_launch_group                   = null
    spot_price                          = null
    spot_type                           = null
    spot_valid_from                     = null
    spot_valid_until                    = null
    spot_wait_for_fulfillment           = null
    tenancy                             = null
    user_data_replace_on_change         = false
    timeouts = {
      create = "60m"
      delete = "30m"
      update = "30m"
    }

    ### DEFAULT TAGS ###
    eip_tags = merge(
      local.common_env_vars.locals.global_tags,
      {
        Environment = local.env
      }
    )
    volume_tags = merge(
      local.common_env_vars.locals.global_tags,
      {
        Environment = local.env
      }
    )
    tags = merge(
      local.common_env_vars.locals.global_tags,
      {
        Environment = local.env
      }
    )
  }
  # NOTE!
  # The EC2 instances below are configured using the user_data_base64 input.
  #	Refer to the terragrunt.hcl configuration file to update or modify the user_data_base64 values if necessary.
  # Ref: terragrunt/aws/dev/us-east-1/compute/ec2/terragrunt.hcl
  # User data Bash scripts can be found in the terragrunt/aws/dev/us-east-1/compute/ec2/userdata directory.
  items = {
    "openvpn" = {
      create                      = true
      create_eip                  = true
      associate_public_ip_address = true
      name                        = "openvpn-${local.env}"
      instance_type               = "t3.micro"
      user_data_replace_on_change = false

      ### IAM ROLE ###
      iam_role_description          = "IAM Role that is used by OpenVPN EC2 instance"
      iam_role_name                 = "OpenVpnEc2Role"
      iam_role_path                 = "/"
      iam_role_permissions_boundary = null
      iam_role_policies             = {}

      ### VOLUMES ###
      root_block_device = {
        encrypted             = true
        delete_on_termination = true
        type                  = "gp3"
        iops                  = 3000
        throughput            = 125 # MB/s
        size                  = 25  # GB
      }

      ### TAGS ###
      iam_role_tags = {
        UsedBy = "OpenVPN"
      }
      eip_tags = {
        Name = "openvpn-${local.env}"
      }
      volume_tags = {
        Name = "openvpn-root-gp3-volume"
      }
      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Name        = "openvpn-${local.env}"
        }
      )
    }
  }
}