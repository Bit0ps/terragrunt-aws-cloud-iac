terraform {
  source = "../../../../vendor/modules/tf-aws-vpc//."
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  vpc_env_vars    = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/network/vpc.hcl")
  region_vars     = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars    = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env        = local.account_vars.locals.environment
  region     = local.region_vars.locals.aws_region
  org_name   = local.common_env_vars.locals.org_name
  account_id = local.account_vars.locals.aws_account_id
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  # Default vpc settings
  manage_default_network_acl    = local.vpc_env_vars.locals.manage_default_network_acl
  manage_default_route_table    = local.vpc_env_vars.locals.manage_default_route_table
  manage_default_security_group = local.vpc_env_vars.locals.manage_default_security_group
  manage_default_vpc            = local.vpc_env_vars.locals.manage_default_vpc

  name = local.vpc_env_vars.locals.name
  cidr = local.vpc_env_vars.locals.cidr

  azs              = local.vpc_env_vars.locals.azs
  private_subnets  = local.vpc_env_vars.locals.private_subnets
  public_subnets   = local.vpc_env_vars.locals.public_subnets
  intra_subnets    = local.vpc_env_vars.locals.intra_subnets
  database_subnets = local.vpc_env_vars.locals.database_subnets

  enable_ipv6 = local.vpc_env_vars.locals.enable_ipv6

  # Enable dns64 support
  public_subnet_enable_dns64   = local.vpc_env_vars.locals.public_subnet_enable_dns64
  private_subnet_enable_dns64  = local.vpc_env_vars.locals.private_subnet_enable_dns64
  intra_subnet_enable_dns64    = local.vpc_env_vars.locals.intra_subnet_enable_dns64
  database_subnet_enable_dns64 = local.vpc_env_vars.locals.database_subnet_enable_dns64

  public_subnet_enable_resource_name_dns_aaaa_record_on_launch   = local.vpc_env_vars.locals.public_subnet_enable_resource_name_dns_aaaa_record_on_launch
  private_subnet_enable_resource_name_dns_aaaa_record_on_launch  = local.vpc_env_vars.locals.private_subnet_enable_resource_name_dns_aaaa_record_on_launch
  intra_subnet_enable_resource_name_dns_aaaa_record_on_launch    = local.vpc_env_vars.locals.intra_subnet_enable_resource_name_dns_aaaa_record_on_launch
  database_subnet_enable_resource_name_dns_aaaa_record_on_launch = local.vpc_env_vars.locals.database_subnet_enable_resource_name_dns_aaaa_record_on_launch

  # Only for public subnets
  map_public_ip_on_launch = local.vpc_env_vars.locals.map_public_ip_on_launch

  enable_nat_gateway     = local.vpc_env_vars.locals.enable_nat_gateway
  single_nat_gateway     = local.vpc_env_vars.locals.single_nat_gateway
  one_nat_gateway_per_az = local.vpc_env_vars.locals.one_nat_gateway_per_az
  enable_dns_hostnames   = local.vpc_env_vars.locals.enable_dns_hostnames
  enable_dns_support     = local.vpc_env_vars.locals.enable_dns_support

  # Tags
  tags                 = local.vpc_env_vars.locals.tags
  private_subnet_tags  = local.vpc_env_vars.locals.private_subnet_tags
  public_subnet_tags   = local.vpc_env_vars.locals.public_subnet_tags
  database_subnet_tags = local.vpc_env_vars.locals.database_subnet_tags
  intra_subnet_tags    = local.vpc_env_vars.locals.intra_subnet_tags
  vpc_tags             = local.vpc_env_vars.locals.vpc_tags
}