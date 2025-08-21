# -------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# -------------------------------------------------------------------------------

locals {
  # -----------------------------------------------------------------------------
  # ACCOUNT-LEVEL VARIABLES
  # -----------------------------------------------------------------------------
  # Automatically load account-level variables
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Extract the variables we need for easy access
  account_name   = local.account_vars.locals.account_name
  account_id     = local.account_vars.locals.aws_account_id
  aws_profile    = local.account_vars.locals.aws_profile
  role_to_assume = local.account_vars.locals.role_to_assume
  aws_region     = local.region_vars.locals.aws_region


  # -----------------------------------------------------------------------------
  # GLOBAL VARIABLES
  # -----------------------------------------------------------------------------
  # Automatically load global variables
  global_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/global.hcl")

  # Extract the variables we need for easy access
  aws_provider_version = local.global_vars.locals.aws_provider_version
  org_name             = local.global_vars.locals.org_name
}

# -----------------------------------------------------------------------------
# GENERATED PROVIDER BLOCK
# -----------------------------------------------------------------------------

# Use OpenTofu instead of Terraform
terraform_binary = "tofu"

# Configure the AWS Provider
generate "aws_provider" {
  path      = "_aws_provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "${local.aws_provider_version}"
    }
    kubectl   = {
      source  = "alekc/kubectl"
      version = "${local.global_vars.locals.kubectl_provider_version}"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "${local.global_vars.locals.helm_provider_version}"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.account_id}"]
  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/${local.role_to_assume}"
  }
}
EOF
}

# -----------------------------------------------------------------------------
# GENERATED REMOTE STATE BLOCK
# -----------------------------------------------------------------------------

remote_state {
  backend = "s3"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  disable_init = tobool(get_env("TERRAGRUNT_DISABLE_INIT", "false"))
  config = {
    encrypt                        = true
    bucket                         = "${local.org_name}-${local.account_name}-${local.aws_region}-opentofu-state"
    key                            = "${path_relative_to_include()}/terraform.tfstate"
    region                         = local.aws_region
    enable_lock_table_ssencryption = true
    # Use SSE-KMS for state encryption if a KMS key ARN is provided in env var TF_STATE_KMS_KEY_ARN
    bucket_sse_kms_key_id = get_env("TF_IAC_STATE_KMS_KEY_ARN")
    # OpenTofu S3-native lockfile (no DynamoDB required)
    use_lockfile   = true
    assume_role = {
      role_arn       = "arn:aws:iam::${local.account_id}:role/${local.role_to_assume}"
      session_name   = "iac"
    }
  }
}

terraform {
  # For any terraform commands that use locking, make sure to configure a lock timeout of 20 minutes.
  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=10m"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder. These are automatically merged into the child
# `terragrunt.hcl` config via the include block.
# ---------------------------------------------------------------------------------------------------------------------

# Configure root level variables that all resources can inherit. This is especially helpful with multi-account configs
# where terraform_remote_state data sources are placed directly into the modules.
inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
  local.global_vars.locals,
)