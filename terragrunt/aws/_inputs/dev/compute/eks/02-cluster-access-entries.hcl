locals {
  common_env_vars  = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  dev_account_vars = local.common_env_vars.locals.dev_account_vars

  account_id   = local.common_env_vars.locals.dev_account_id
  env          = local.common_env_vars.locals.dev_env
  org_name     = local.common_env_vars.locals.org_name
  cluster_name = "${local.org_name}-${local.env}"

  access_entries = {
    "admin" = {
      cluster_name      = local.cluster_name
      kubernetes_groups = ["admin"]
      principal_arn     = "arn:aws:iam::${local.account_id}:role/DevKubeAdmin"
      user_name         = "kubeAdmin"

      policy_associations = {
        AmazonEKSAdminPolicy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    },
    "readonly" = {
      cluster_name      = local.cluster_name
      kubernetes_groups = ["view"]
      principal_arn     = "arn:aws:iam::${local.account_id}:role/DevKubeReadOnly"
      user_name         = "kubeReadOnly"

      policy_associations = {
        AmazonEKSViewPolicy = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}