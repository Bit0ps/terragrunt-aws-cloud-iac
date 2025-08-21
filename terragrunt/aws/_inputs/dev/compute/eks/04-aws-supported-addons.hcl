locals {
  common_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")

  account_id = local.common_env_vars.locals.dev_account_id
  env        = local.common_env_vars.locals.dev_env
  org_name   = local.common_env_vars.locals.org_name

  # AWS SUPPORTED ADDONS
  # Ref: https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html
  addons = {
    "coredns" = {
      most_recent = true
    }
    "aws-ebs-csi-driver" = {
      most_recent = true
    }
    "eks-pod-identity-agent" = {
      most_recent = true
    }
    "kube-proxy" = {
      most_recent = true
    }
    "vpc-cni" = {
      most_recent    = true
      before_compute = true
    }
  }
  addons_timeouts = {
    create = "30m"
    update = "15m"
    delete = "30m"
  }
}