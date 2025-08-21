# -------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION (HELM PILLAR)
# -------------------------------------------------------------------------------

locals {
  # Load AWS pillar (for state bucket and role), plus Helm pillar globals/region
  aws_global_vars  = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/global.hcl")
  aws_account_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/dev/account.hcl")
  helm_global_vars = read_terragrunt_config(find_in_parent_folders("_global.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  org_name       = local.aws_global_vars.locals.org_name
  account_name   = local.aws_account_vars.locals.account_name
  account_id     = local.aws_account_vars.locals.aws_account_id
  role_to_assume = local.aws_account_vars.locals.role_to_assume
  aws_region     = local.region_vars.locals.aws_region
}

terraform_binary = "tofu"

# Remote state matches AWS pillar conventions
remote_state {
  backend = "s3"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
  config = {
    encrypt      = true
    bucket       = "${local.org_name}-${local.account_name}-${local.aws_region}-opentofu-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    use_lockfile = true
    bucket_sse_kms_key_id = get_env("TF_IAC_STATE_KMS_KEY_ARN")
    assume_role = {
      role_arn     = "arn:aws:iam::${local.account_id}:role/${local.role_to_assume}"
      session_name = "iac"
    }
  }
}

terraform {
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=10m"]
  }
}

inputs = merge(
  local.aws_global_vars.locals,
  local.aws_account_vars.locals,
  local.region_vars.locals,
)

# Generate kubernetes and helm providers (use kubeconfig/context)
generate "k8s_helm_providers" {
  path      = "_k8s_helm_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "${local.helm_global_vars.locals.kubernetes_provider_version}"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "${local.helm_global_vars.locals.helm_provider_version}"
    }
  }
}

provider "kubernetes" {
  config_path    = coalesce(getenv("KUBECONFIG"), "~/.kube/config")
  config_context = getenv("KUBE_CONTEXT")
}

provider "helm" {
  kubernetes {
    config_path    = coalesce(getenv("KUBECONFIG"), "~/.kube/config")
    config_context = getenv("KUBE_CONTEXT")
  }
}
EOF
}


