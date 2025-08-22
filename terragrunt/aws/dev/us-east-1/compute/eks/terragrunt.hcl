terraform {
  source = "../../../../vendor/modules/tf-aws-eks//."
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../../network/vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-00000000000000001", "subnet-00000000000000002", "subnet-00000000000000003"]
    intra_subnets   = ["subnet-00000000000000011", "subnet-00000000000000012", "subnet-00000000000000013"]
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "kms" {
  config_path = "../../security/kms"
  mock_outputs = {
    wrapper = {
      cloudwatch_logs = { key_arn = "arn:aws:kms:us-east-1:111122223333:key/mock-cloudwatch" }
      ec2_ebs         = { key_arn = "arn:aws:kms:us-east-1:111122223333:key/mock-ebs" }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "openvpn_sg" {
  config_path = "../../security/security-groups/openvpn"
  mock_outputs = {
    security_group_id = "sg-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependencies {
  paths = [
    "../../compute/ec2",
    "../../security/key-pair",
    "../../../_global/iam/roles/assumable-roles",
    "../../security/kms",
     "../../network/vpc"
  ]
}

generate "helm" {
  path      = "_k8s_auth.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  provider "helm" {
    kubernetes {
      host                   = module.eks.cluster_endpoint
      cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        # This requires the awscli to be installed locally where Terraform is executed
        args = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--role-arn", "arn:aws:iam::${local.account_id}:role/${get_env("IAM_ASSUME_ROLE", "infraAsCode")}"]
      }
    }
  }
EOF
}

################################################################################
# IAM Service-linked roles
# This is used by the nodes launched by Karpenter
################################################################################
generate "spot_service_linked_role" {
  path      = "_spot_service_linked_role.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  resource "aws_iam_service_linked_role" "AWSServiceRoleForEC2Spot" {
    count = var.create_ec2_spot_iam_service_linked_role ? 1 : 0
    aws_service_name = "spot.amazonaws.com"
    tags = {
      Name = "AWSServiceRoleForEC2Spot"
    }
  }
  resource "aws_iam_service_linked_role" "AWSServiceRoleForEC2SpotFleet" {
    count = var.create_ec2_spot_fleet_iam_service_linked_role ? 1 : 0
    aws_service_name = "spotfleet.amazonaws.com"
    tags = {
      Name = "AWSServiceRoleForEC2SpotFleet"
    }
  }
  variable "create_ec2_spot_iam_service_linked_role" {
    description = "The Service Linked Role for EC2 Spot Instances"
    type        = bool
    default     = ${local.create_ec2_spot_iam_service_linked_role}
  }
  variable "create_ec2_spot_fleet_iam_service_linked_role" {
    description = "The Service Linked Role for EC2 Spot Fleet"
    type        = bool
    default     = ${local.create_ec2_spot_fleet_iam_service_linked_role}
  }
EOF
}
locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars                    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  eks_cluster_env_vars               = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/01-cluster.hcl")
  eks_access_entries_env_vars        = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/02-cluster-access-entries.hcl")
  eks_additional_sg_rules_env_vars   = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/03-additional-security-groups.hcl")
  eks_aws_supported_addones_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/04-aws-supported-addons.hcl")
  eksmanaged_nodegroups_env_vars     = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/06-eksmanaged-nodegroups.hcl")
  region_vars                        = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars                       = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env        = local.account_vars.locals.environment
  region     = local.region_vars.locals.aws_region
  org_name   = local.common_env_vars.locals.org_name
  account_id = local.account_vars.locals.aws_account_id

  create_ec2_spot_iam_service_linked_role       = local.eks_cluster_env_vars.locals.create_ec2_spot_iam_service_linked_role
  create_ec2_spot_fleet_iam_service_linked_role = local.eks_cluster_env_vars.locals.create_ec2_spot_fleet_iam_service_linked_role
  timestamp                                     = "${timestamp()}"
  timestamp_sanitized                           = "${replace("${local.timestamp}", "/[- TZ:]/", "")}"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  access_entries                               = local.eks_access_entries_env_vars.locals.access_entries
  attach_cluster_encryption_policy             = local.eks_cluster_env_vars.locals.cluster.opsfleet.attach_cluster_encryption_policy
  authentication_mode                          = local.eks_cluster_env_vars.locals.cluster.opsfleet.authentication_mode
  cloudwatch_log_group_class                   = local.eks_cluster_env_vars.locals.cluster.opsfleet.cloudwatch_log_group_class
  cloudwatch_log_group_kms_key_arn             = "${flatten([for key, value in dependency.kms.outputs.wrapper : value.key_arn if key == "cloudwatch_logs"])}"
  cloudwatch_log_group_retention_in_days       = local.eks_cluster_env_vars.locals.cluster.opsfleet.cloudwatch_log_group_retention_in_days
  additional_security_group_ids                = local.eks_cluster_env_vars.locals.cluster.opsfleet.additional_security_group_ids
  addons                                       = local.eks_aws_supported_addones_env_vars.locals.addons
  addons_timeouts                              = local.eks_aws_supported_addones_env_vars.locals.addons_timeouts
  compute_config                               = local.eks_cluster_env_vars.locals.cluster.opsfleet.compute_config
  enabled_log_types                            = local.eks_cluster_env_vars.locals.cluster.opsfleet.enabled_log_types
  encryption_config                            = local.eks_cluster_env_vars.locals.cluster.opsfleet.encryption_config
  encryption_policy_description                = local.eks_cluster_env_vars.locals.cluster.opsfleet.encryption_policy_description
  encryption_policy_name                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.encryption_policy_name
  encryption_policy_path                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.encryption_policy_path
  encryption_policy_use_name_prefix            = local.eks_cluster_env_vars.locals.cluster.opsfleet.encryption_policy_use_name_prefix
  endpoint_private_access                      = local.eks_cluster_env_vars.locals.cluster.opsfleet.endpoint_private_access
  endpoint_public_access                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.endpoint_public_access
  endpoint_public_access_cidrs                 = local.eks_cluster_env_vars.locals.cluster.opsfleet.endpoint_public_access_cidrs
  identity_providers                           = local.eks_cluster_env_vars.locals.cluster.opsfleet.identity_providers
  ip_family                                    = local.eks_cluster_env_vars.locals.cluster.opsfleet.ip_family
  name                                         = local.eks_cluster_env_vars.locals.cluster.opsfleet.name
  remote_network_config                        = local.eks_cluster_env_vars.locals.cluster.opsfleet.remote_network_config
  security_group_description                   = local.eks_cluster_env_vars.locals.cluster.opsfleet.security_group_description
  security_group_id                            = local.eks_cluster_env_vars.locals.cluster.opsfleet.security_group_id
  security_group_name                          = local.eks_cluster_env_vars.locals.cluster.opsfleet.security_group_name
  security_group_use_name_prefix               = local.eks_cluster_env_vars.locals.cluster.opsfleet.security_group_use_name_prefix
  timeouts                                     = local.eks_cluster_env_vars.locals.cluster.opsfleet.timeouts
  upgrade_policy                               = local.eks_cluster_env_vars.locals.cluster.opsfleet.upgrade_policy
  kubernetes_version                           = local.eks_cluster_env_vars.locals.cluster.opsfleet.kubernetes_version
  zonal_shift_config                           = local.eks_cluster_env_vars.locals.cluster.opsfleet.zonal_shift_config
  region                                       = local.region
  control_plane_subnet_ids                     = slice(dependency.vpc.outputs.intra_subnets, 0, 2)
  create                                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.create
  create_cloudwatch_log_group                  = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_cloudwatch_log_group
  create_primary_security_group_tags           = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_primary_security_group_tags
  create_security_group                        = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_security_group
  create_cni_ipv6_iam_policy                   = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_cni_ipv6_iam_policy
  create_iam_role                              = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_iam_role
  create_kms_key                               = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_kms_key
  create_node_iam_role                         = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_node_iam_role
  create_node_security_group                   = local.eks_cluster_env_vars.locals.cluster.opsfleet.create_node_security_group
  custom_oidc_thumbprints                      = local.eks_cluster_env_vars.locals.cluster.opsfleet.custom_oidc_thumbprints
  dataplane_wait_duration                      = local.eks_cluster_env_vars.locals.cluster.opsfleet.dataplane_wait_duration
  deletion_protection                          = local.eks_cluster_env_vars.locals.cluster.opsfleet.deletion_protection
  enable_auto_mode_custom_tags                 = local.eks_cluster_env_vars.locals.cluster.opsfleet.enable_auto_mode_custom_tags
  enable_cluster_creator_admin_permissions     = local.eks_cluster_env_vars.locals.cluster.opsfleet.enable_cluster_creator_admin_permissions
  enable_kms_key_rotation                      = local.eks_cluster_env_vars.locals.cluster.opsfleet.enable_kms_key_rotation
  fargate_profile_defaults                     = local.eks_cluster_env_vars.locals.cluster.opsfleet.fargate_profile_defaults
  fargate_profiles                             = local.eks_cluster_env_vars.locals.cluster.opsfleet.fargate_profiles
  iam_role_additional_policies                 = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_additional_policies
  iam_role_arn                                 = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_arn
  iam_role_description                         = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_description
  iam_role_name                                = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_name
  iam_role_path                                = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_path
  iam_role_permissions_boundary                = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_permissions_boundary
  iam_role_use_name_prefix                     = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_use_name_prefix
  include_oidc_root_ca_thumbprint              = local.eks_cluster_env_vars.locals.cluster.opsfleet.include_oidc_root_ca_thumbprint
  kms_key_administrators                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_administrators
  kms_key_aliases                              = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_aliases
  kms_key_deletion_window_in_days              = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_deletion_window_in_days
  kms_key_description                          = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_description
  kms_key_enable_default_policy                = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_enable_default_policy
  kms_key_override_policy_documents            = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_override_policy_documents
  kms_key_owners                               = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_owners
  kms_key_service_users                        = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_service_users
  kms_key_source_policy_documents              = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_source_policy_documents
  kms_key_users                                = local.eks_cluster_env_vars.locals.cluster.opsfleet.kms_key_users
  node_iam_role_additional_policies            = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_additional_policies
  node_iam_role_description                    = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_description
  node_iam_role_name                           = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_name
  node_iam_role_path                           = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_path
  node_iam_role_permissions_boundary           = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_permissions_boundary
  node_iam_role_use_name_prefix                = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_use_name_prefix
  node_security_group_description              = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_security_group_description
  node_security_group_enable_recommended_rules = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_security_group_enable_recommended_rules
  node_security_group_id                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_security_group_id
  node_security_group_name                     = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_security_group_name
  node_security_group_use_name_prefix          = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_security_group_use_name_prefix
  openid_connect_audiences                     = local.eks_cluster_env_vars.locals.cluster.opsfleet.openid_connect_audiences
  outpost_config                               = local.eks_cluster_env_vars.locals.cluster.opsfleet.outpost_config
  prefix_separator                             = local.eks_cluster_env_vars.locals.cluster.opsfleet.prefix_separator
  putin_khuylo                                 = true
  subnet_ids                                   = dependency.vpc.outputs.private_subnets
  vpc_id                                       = dependency.vpc.outputs.vpc_id

  ### SECURITY GROUPS ###
  security_group_additional_rules = {
    ingress_openvpn_tcp = {
      description              = local.eks_additional_sg_rules_env_vars.locals.security_group_additional_rules.1.description
      protocol                 = local.eks_additional_sg_rules_env_vars.locals.security_group_additional_rules.1.protocol
      from_port                = local.eks_additional_sg_rules_env_vars.locals.security_group_additional_rules.1.from_port
      to_port                  = local.eks_additional_sg_rules_env_vars.locals.security_group_additional_rules.1.to_port
      type                     = local.eks_additional_sg_rules_env_vars.locals.security_group_additional_rules.1.type
      source_security_group_id = dependency.openvpn_sg.outputs.security_group_id
    }
  }
  node_security_group_additional_rules = local.eks_additional_sg_rules_env_vars.locals.node_security_group_additional_rules

  ### EKS MANAGED NODE GROUPS ###
  eks_managed_node_group_defaults = {
    ami_id                                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.ami_id
    ami_release_version                    = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.ami_release_version
    ami_type                               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.ami_type
    block_device_mappings                  = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.block_device_mappings
    bootstrap_extra_args                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.bootstrap_extra_args
    capacity_reservation_specification     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.capacity_reservation_specification
    capacity_type                          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.capacity_type
    cloudinit_post_nodeadm                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.cloudinit_post_nodeadm
    cloudinit_pre_nodeadm                  = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.cloudinit_pre_nodeadm
    ip_family                              = local.eks_cluster_env_vars.locals.cluster.opsfleet.ip_family
    name                                   = local.eks_cluster_env_vars.locals.cluster.opsfleet.name
    cluster_service_cidr                   = local.eks_cluster_env_vars.locals.cluster.opsfleet.service_ipv4_cidr
    kubernetes_version                     = local.eks_cluster_env_vars.locals.cluster.opsfleet.kubernetes_version
    cpu_options                            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.cpu_options
    create                                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.create
    create_iam_role                        = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.create_iam_role
    create_iam_role_policy                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.create_iam_role_policy
    create_launch_template                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.create_launch_template
    create_placement_group                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.create_placement_group
    credit_specification                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.credit_specification
    desired_size                           = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.disk_size
    disable_api_termination                = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.disable_api_termination
    disk_size                              = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.disk_size
    ebs_optimized                          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.ebs_optimized
    efa_indices                            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.efa_indices
    enable_bootstrap_user_data             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.enable_bootstrap_user_data
    enable_efa_only                        = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.enable_efa_only
    enable_efa_support                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.enable_efa_support
    enable_monitoring                      = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.enable_monitoring
    enclave_options                        = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.enclave_options
    force_update_version                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.force_update_version
    iam_role_additional_policies           = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_additional_policies
    iam_role_attach_cni_policy             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_attach_cni_policy
    iam_role_path                          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_path
    iam_role_permissions_boundary          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_permissions_boundary
    iam_role_policy_statements             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_policy_statements
    iam_role_tags                          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_tags
    iam_role_use_name_prefix               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.iam_role_use_name_prefix
    instance_market_options                = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.instance_market_options
    instance_types                         = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.instance_types
    kernel_id                              = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.kernel_id
    key_name                               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.key_name
    labels                                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.labels
    launch_template_default_version        = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_default_version
    launch_template_description            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_description
    launch_template_id                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_id
    launch_template_name                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_name
    launch_template_tags                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_tags
    launch_template_use_name_prefix        = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_use_name_prefix
    launch_template_version                = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.launch_template_version
    license_specifications                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.license_specifications
    maintenance_options                    = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.maintenance_options
    max_size                               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.max_size
    metadata_options                       = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.metadata_options
    min_size                               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.min_size
    network_interfaces                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.network_interfaces
    placement                              = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.placement
    post_bootstrap_user_data               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.post_bootstrap_user_data
    pre_bootstrap_user_data                = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.pre_bootstrap_user_data
    private_dns_name_options               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.private_dns_name_options
    ram_disk_id                            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.ram_disk_id
    remote_access                          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.remote_access
    subnet_ids                             = dependency.vpc.outputs.private_subnets
    tag_specifications                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.tag_specifications
    tags                                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.tags
    taints                                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.taints
    timeouts                               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.timeouts
    update_config                          = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.update_config
    update_launch_template_default_version = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.update_launch_template_default_version
    use_custom_launch_template             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.use_custom_launch_template
    use_latest_ami_release_version         = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.use_latest_ami_release_version
    use_name_prefix                        = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.use_name_prefix
    user_data_template_path                = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.user_data_template_path
    vpc_security_group_ids                 = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.defaults.vpc_security_group_ids
  }
  ### EKS MANAGED NODE GROUP №1 ###
  eks_managed_node_groups = {
    "eksmanaged-bottlerocket-critical" = {
      create                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.create
      name                       = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.name
      use_name_prefix            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.use_name_prefix
      iam_role_name              = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.iam_role_name
      iam_role_description       = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.iam_role_description
      instance_types             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.instance_types
      max_size                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.max_size
      min_size                   = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.min_size
      desired_size               = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.desired_size
      enable_bootstrap_user_data = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.enable_bootstrap_user_data
      labels                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.labels
      taints                     = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.taints
      iam_role_tags              = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.iam_role_tags
      tags                       = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.tags

      block_device_mappings = {
        # Encrypted EBS root volume
        root = {
          device_name = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_device_name
          ebs = {
            volume_size           = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_volume_size
            volume_type           = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_volume_type
            iops                  = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_volume_iops
            throughput            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_volume_throughput
            encrypted             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_volume_encrypted
            kms_key_arn           = "${flatten([for key, value in dependency.kms.outputs.wrapper : value.key_arn if key == "ec2_ebs"])}"
            delete_on_termination = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.root_volume_delete_on_termination
          }
        }
        # Encrypted EBS container volume
        container = {
          device_name = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_device_name
          ebs = {
            volume_size           = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_volume_size
            volume_type           = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_volume_type
            iops                  = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_volume_iops
            throughput            = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_volume_throughput
            encrypted             = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_volume_encrypted
            kms_key_arn           = "${flatten([for key, value in dependency.kms.outputs.wrapper : value.key_arn if key == "ec2_ebs"])}"
            delete_on_termination = local.eksmanaged_nodegroups_env_vars.locals.eks_managed_node_groups.eksmanaged_bottlerocket_critical.container_volume_delete_on_termination
          }
        }
      }
    }
  }
  ### TAGS ###
  cloudwatch_log_group_tags = local.eks_cluster_env_vars.locals.cluster.opsfleet.cloudwatch_log_group_tags
  security_group_tags       = local.eks_cluster_env_vars.locals.cluster.opsfleet.security_group_tags
  encryption_policy_tags    = local.eks_cluster_env_vars.locals.cluster.opsfleet.encryption_policy_tags
  iam_role_tags             = local.eks_cluster_env_vars.locals.cluster.opsfleet.iam_role_tags
  node_iam_role_tags        = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_iam_role_tags
  node_security_group_tags  = local.eks_cluster_env_vars.locals.cluster.opsfleet.node_security_group_tags
  tags                      = local.eks_cluster_env_vars.locals.cluster.opsfleet.tags
  cluster_tags = merge(
    local.eks_cluster_env_vars.locals.cluster.opsfleet.cluster_tags,
    {
      Version = "${local.eks_cluster_env_vars.locals.cluster.opsfleet.kubernetes_version}"
    }
  )
}