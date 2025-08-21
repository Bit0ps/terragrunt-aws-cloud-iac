terraform_binary = "tofu"

locals {
  # Standalone bootstrap: resolve dynamically with fallbacks
  account_id = coalesce(
    trimspace(run_cmd("--terragrunt-quiet","bash", "-lc", "aws sts get-caller-identity --query Account --output text 2>/dev/null || true")),
    get_env("AWS_ACCOUNT_ID", "")
  )
  region = coalesce(
    get_env("AWS_REGION", ""),
    get_env("AWS_DEFAULT_REGION", ""),
    trimspace(run_cmd("--terragrunt-quiet", "bash", "-lc", "aws configure list --json 2>/dev/null | jq -r '.region.value // empty' || true")),
    "us-east-1"
  )

  user_name = "terragrunt"
  role_name = "infraAsCode"
}

# Local state to avoid S3 dependency during bootstrap
remote_state {
  backend = "local"
  generate = {
    path      = "_backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    path = "${get_terragrunt_dir()}/.state/terraform.tfstate"
  }
}

terraform {
  source = "${get_path_to_repo_root()}/terragrunt/aws/_modules/aws-account-bootstrap"
}

inputs = {
  user_name                      = local.user_name
  role_name                      = local.role_name
  role_max_session_duration      = 3600
  permissions_boundary_arn       = null
  kms_key_alias                  = "alias/terraform-state"
  create_access_key              = true
  attach_user_assume_role_policy = true
  create_iam_instance_profile    = true

  # Policies
  iam_role_policy_json = file("${get_path_to_repo_root()}/terragrunt/aws/_policies/iam/iacAssumeRole.json")
  kms_key_policy_json = templatefile("${get_path_to_repo_root()}/terragrunt/aws/_policies/kms/iacStateKey.json", {
    account_id = local.account_id,
    role_name  = local.role_name,
    user_name  = local.user_name
  })
  tags = {
    Project    = "opsfleet"
    Env        = "bootstrap"
    Managed_by = "Terragrunt"
  }
}


