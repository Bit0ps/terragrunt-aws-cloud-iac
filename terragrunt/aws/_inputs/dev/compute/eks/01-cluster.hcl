locals {
  common_env_vars  = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  dev_account_vars = local.common_env_vars.locals.dev_account_vars

  account_id = local.common_env_vars.locals.dev_account_id
  env        = local.common_env_vars.locals.dev_env
  org_name   = local.common_env_vars.locals.org_name

  # Create Service-linked roles. Required for Karpenter provisioner!
  create_ec2_spot_iam_service_linked_role       = true
  create_ec2_spot_fleet_iam_service_linked_role = true

  #################################################
  # AWS EKS MODULE VARIABLES
  # Terraform module to create an Elastic Kubernetes (EKS) cluster and associated resources
  # https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  #################################################
  cluster = {
    "opsfleet" = {
      create                             = true
      create_aws_auth_configmap          = false
      create_primary_security_group_tags = true
      create_cni_ipv6_iam_policy         = false # Determines whether to create an AmazonEKS_CNI_IPv6_Policy
      name                               = "${local.org_name}-${local.env}"
      kubernetes_version                 = "1.33"
      ip_family                          = "ipv4"
      endpoint_private_access            = true
      endpoint_public_access             = false
      endpoint_public_access_cidrs       = ["0.0.0.0/0"]   # List of CIDR blocks which can access the Amazon EKS public API server endpoint
      service_ipv4_cidr                  = "172.20.0.0/16" # https://kubernetes.io/blog/2022/05/23/service-ip-dynamic-and-static-allocation/
      service_ipv6_cidr                  = null            # Kubernetes assigns service addresses from the unique local address range (fc00::/7) because you can't specify a custom IPv6 CIDR block when you create the cluster
      dataplane_wait_duration            = "30s"           # Duration to wait after the EKS cluster has become active before creating the dataplane components (EKS managed node group(s), self-managed node group(s), Fargate profile(s))
      deletion_protection                = false
      prefix_separator                   = "-"
      timeouts = {
        create = "180m"
        update = "120m"
        delete = "120m"
      }

      upgrade_policy = {
        support_type = "STANDARD"
      }
      remote_network_config = null
      zonal_shift_config    = null

      # AUTH
      create_iam_role                          = true
      enable_cluster_creator_admin_permissions = true
      authentication_mode                      = "API"
      iam_role_arn                             = null # Existing IAM role ARN for the cluster. Required if create_iam_role is set to false
      iam_role_name                            = "EKSClusterRole"
      iam_role_description                     = "Amazon EKS - Cluster role. The role make calls to other AWS services on user behalf to manage the resources that user use with the service."
      iam_role_path                            = "/"
      iam_role_permissions_boundary            = null # ARN of the policy that is used to set the permissions boundary for the IAM role
      iam_role_use_name_prefix                 = false
      iam_role_additional_policies             = {}

      # ENCRYPTION
      create_kms_key                    = true
      attach_cluster_encryption_policy  = true
      encryption_config                 = { resources = ["secrets"] }
      encryption_policy_name            = "EKSClusterEncryptionPolicy"
      encryption_policy_description     = "Cluster encryption policy to encrypt k8s secrets"
      encryption_policy_path            = null
      encryption_policy_use_name_prefix = true
      enable_kms_key_rotation           = true
      kms_key_deletion_window_in_days   = 14
      kms_key_description               = "Encryption key for ${local.org_name}-${local.env} EKS cluster to encrypt k8s secrets"
      kms_key_enable_default_policy     = true
      kms_key_owners                    = []
      kms_key_administrators            = ["arn:aws:iam::${local.account_id}:role/DevAdminAccessAssumeRole", "arn:aws:iam::${local.account_id}:role/${local.dev_account_vars.locals.role_to_assume}"]
      kms_key_aliases                   = [] # A list of aliases to create. Note - due to the use of toset(), values must be static strings and not computed values
      kms_key_service_users             = []
      kms_key_users                     = []
      kms_key_source_policy_documents   = [] # List of IAM policy documents that are merged together into the exported document. Statements must have unique sids
      kms_key_override_policy_documents = [] # List of IAM policy documents that are merged together into the exported document. In merging, statements with non-blank sids will override statements with the same sid

      # OIDC IDENTITY PROVIDER
      include_oidc_root_ca_thumbprint = true # Determines whether to include the root CA thumbprint in the OpenID Connect (OIDC) identity provider's server certificate(s)
      identity_providers              = {}
      openid_connect_audiences        = []
      custom_oidc_thumbprints         = [] # Additional list of server certificate thumbprints for the OpenID Connect (OIDC) identity provider's server certificate(s)

      # SECURITY
      create_security_group          = true
      create_node_security_group     = true
      security_group_name            = "${local.org_name}-eks-cluster-sg-${local.env}"
      security_group_description     = "EKS cluster primary security group"
      security_group_use_name_prefix = false
      security_group_id              = "" # Existing security group ID to be attached to the cluster
      additional_security_group_ids  = [] # List of additional, externally created security group IDs to attach to the cluster control plane

      node_security_group_enable_recommended_rules = true
      node_security_group_id                       = "" # ID of an existing security group to attach to the node groups created
      node_security_group_name                     = "${local.org_name}-eks-nodes-shared-sg-${local.env}"
      node_security_group_description              = "EKS node shared security group"
      node_security_group_use_name_prefix          = true
      node_security_group_additional_rules         = {} # List of additional security group rules to add to the node security group created. Set source_security_group = true inside rules to set the security_group as source

      # LOGS
      create_cloudwatch_log_group            = true
      enabled_log_types                      = ["audit", "authenticator", "api", "controllerManager", "scheduler"]
      cloudwatch_log_group_class             = "STANDARD" # Possible values are: STANDARD or INFREQUENT_ACCESS
      cloudwatch_log_group_retention_in_days = 14

      # EKS AUTO NODE
      create_node_iam_role               = true
      enable_auto_mode_custom_tags       = true # Determines whether to enable permissions for custom tags resources created by EKS Auto Mode
      node_iam_role_additional_policies  = {}
      node_iam_role_description          = "Roles that is used by EKS Auto Mode. EKS Auto Mode extends AWS management of Kubernetes clusters beyond the cluster itself, to allow AWS to also set up and manage the infrastructure that enables the smooth operation of your workloads."
      node_iam_role_name                 = "EKSAutoNodeRole"
      node_iam_role_path                 = "/"
      node_iam_role_permissions_boundary = null
      node_iam_role_use_name_prefix      = true
      compute_config                     = null


      # FARGATE
      fargate_profile_defaults = {}
      fargate_profiles         = {}

      # OUTPOST
      outpost_config = null

      # TAGS
      cloudwatch_log_group_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          UsedBy = "EKS"
        }
      )

      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Name        = "${local.org_name}-${local.env}"
          Environment = local.env
          UsedBy      = "EKS"
        }
      )

      encryption_policy_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Name        = "EKSClusterEncryptionPolicy"
          UsedBy      = "EKS"
        }
      )

      security_group_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          UsedBy      = "EKS"
        }
      )

      iam_role_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Name        = "EKSClusterRole"
          Purpose     = "Protector of the kubelet"
          Environment = local.env
          UsedBy      = "EKS"
        }
      )

      node_iam_role_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Name        = "EKSAutoNodeRole"
          Environment = local.env
          UsedBy      = "EKS"
        }
      )

      node_security_group_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          "karpenter.sh/discovery" = "${local.org_name}-${local.env}"
          Environment              = local.env
          UsedBy                   = "EKS"
        }
      )

      cluster_tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          GithubRepo  = "https://github.com/terraform-aws-modules/terraform-aws-eks"
          UsedBy      = "EKS"
        }
      )
    }
  }
}