locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  org_name        = local.common_env_vars.locals.org_name
  env             = local.common_env_vars.locals.dev_env
  region          = local.common_env_vars.locals.default_region

  #################################################
  # AWS VPC MODULE VARIABLES
  # https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
  #################################################

  # Default vpc settings
  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false
  manage_default_vpc            = false

  name = "${local.env}-test-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
  # EKS: allocate at least /20 for private and public subnets per AZ (sufficient IPs for nodes and LoadBalancers)
  private_subnets  = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  public_subnets   = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
  # Non-overlapping smaller ranges for intra and database subnets
  intra_subnets    = ["10.0.192.0/24", "10.0.193.0/24", "10.0.194.0/24"]
  database_subnets = ["10.0.200.0/24", "10.0.201.0/24", "10.0.202.0/24"]

  enable_ipv6 = true

  # Enable dns64 support
  public_subnet_enable_dns64   = false
  private_subnet_enable_dns64  = false
  intra_subnet_enable_dns64    = false
  database_subnet_enable_dns64 = false

  public_subnet_enable_resource_name_dns_aaaa_record_on_launch   = false
  private_subnet_enable_resource_name_dns_aaaa_record_on_launch  = false
  intra_subnet_enable_resource_name_dns_aaaa_record_on_launch    = false
  database_subnet_enable_resource_name_dns_aaaa_record_on_launch = false

  # Only for public subnets
  map_public_ip_on_launch = true

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  
  # Tags
  tags = merge(
    local.common_env_vars.locals.global_tags,
    {
      Environment = local.env
    }
  )
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.org_name}-${local.env}" = "shared"
    "kubernetes.io/role/elb"                               = "1"
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery/subnets" = "public"
    "groupname"                      = "public"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/${local.org_name}-${local.env}" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery"         = "${local.org_name}-${local.env}"
    "karpenter.sh/discovery/subnets" = "private"
    "groupname"                      = "private"
  }
  database_subnet_tags = {
    "groupname"           = "database"
  }
  intra_subnet_tags = {
    "groupname"           = "isolated"
  }
  vpc_tags = {
    "kubernetes.io/cluster/${local.org_name}-${local.env}" = "shared"
  }
}