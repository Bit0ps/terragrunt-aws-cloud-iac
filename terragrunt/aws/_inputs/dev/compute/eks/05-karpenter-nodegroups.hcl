locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")

  account_id = local.common_env_vars.locals.dev_account_id
  env        = local.common_env_vars.locals.dev_env
  org_name   = local.common_env_vars.locals.org_name
  region     = local.common_env_vars.locals.default_region

  # Karpenter helm chart local variables (Karpenter CRDs | Karpenter | EC2 Node Classes | Nodepools)
  helm_chart = {
    karpenter_crd = {
      wait = true
    },
    karpenter = {
      version      = "1.6.2"
      wait         = true
      skip_crds    = true
      reuse_values = true
    }
  }

  karpenter = {
    create                          = true
    create_access_entry             = true
    create_iam_role                 = true
    create_instance_profile         = false
    create_node_iam_role            = true
    create_pod_identity_association = true
    enable_spot_termination         = true
    access_entry_type               = "EC2_LINUX"
    ami_id_ssm_parameter_arns = [
      "arn:aws:ssm:us-east-1::parameter/aws/service/bottlerocket/*",
      "arn:aws:ssm:us-east-1::parameter/aws/service/canonical/*"
    ]
    iam_policy_description                  = "Karpenter controller IAM role"
    iam_policy_name                         = "KarpenterController"
    iam_policy_path                         = "/"
    iam_policy_statements                   = []
    iam_policy_use_name_prefix              = true
    iam_role_description                    = "Karpenter controller IAM role"
    iam_role_max_session_duration           = null
    iam_role_name                           = "KarpenterController"
    iam_role_path                           = "/"
    iam_role_permissions_boundary_arn       = null
    iam_role_policies                       = {}
    iam_role_use_name_prefix                = false
    namespace                               = "kube-system" # Namespace to associate with the Karpenter Pod Identity
    node_iam_role_additional_policies       = { AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" }
    node_iam_role_arn                       = null # Existing IAM role ARN for the IAM instance profile. Required if create_iam_role is set to false
    node_iam_role_attach_cni_policy         = true
    node_iam_role_description               = "Karpenter-managed IAM role for EKS Nodes"
    node_iam_role_max_session_duration      = 3600 # One hour
    node_iam_role_name                      = "EKSKarpenterManagedNodeGroupRole"
    node_iam_role_path                      = "/"
    node_iam_role_permissions_boundary      = null
    node_iam_role_use_name_prefix           = false
    queue_kms_data_key_reuse_period_seconds = null  # The length of time, in seconds, for which Amazon SQS can reuse a data key to encrypt or decrypt messages before calling AWS KMS again
    queue_managed_sse_enabled               = false # Boolean to enable server-side encryption (SSE) of message content with SQS-owned encryption keys. Conflicts with queue_kms_master_key_id.
    queue_name                              = "karpenterController"
    region                                  = local.region
    rule_name_prefix                        = "Karpenter"
    service_account                         = "karpenter"

    # TAGS
    iam_role_tags = merge(
      local.common_env_vars.locals.global_tags,
      {
        Environment = local.env
        Karpenter   = "true"
        UsedBy      = "EKS"
        Name        = "KarpenterController"
      }
    )

    node_iam_role_tags = merge(
      local.common_env_vars.locals.global_tags,
      {
        Environment = local.env
        Karpenter   = "true"
        UsedBy      = "EKS"
        Name        = "EKSKarpenterManagedNodeGroupRole"
      }
    )

    tags = merge(
      local.common_env_vars.locals.global_tags,
      {
        Environment = local.env
        Karpenter   = "true"
        UsedBy      = "EKS"
      }
    )
  }
}