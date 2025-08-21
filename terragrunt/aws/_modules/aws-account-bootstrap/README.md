### aws-account-bootstrap (custom module)

Creates a bootstrap IAM user, an assumable IAM role for IaC operations, and a KMS key (with alias) for encrypting remote state. Optionally creates an IAM instance profile for the role.

#### What it creates
- IAM user (e.g., `terragrunt`) and optional access key
- IAM role (e.g., `infraAsCode`) with an attached policy you supply
- KMS key and alias (default alias `alias/terraform-state`), with key policy allowing the role and user
- Optional IAM instance profile mapped to the role (toggle via input)

#### Inputs
- `user_name` (string): Bootstrap IAM user name
- `role_name` (string): IaC role name
- `iam_role_policy_json` (string): JSON policy document to attach to the role
- `kms_key_alias` (string, default `alias/terraform-state`)
- `kms_key_policy_json` (string, optional): Custom KMS key policy JSON (overrides default)
- `create_access_key` (bool, default `true`)
- `attach_user_assume_role_policy` (bool, default `true`)
- `role_max_session_duration` (number, default `3600`)
- `permissions_boundary_arn` (string, optional)
- `create_iam_instance_profile` (bool, default `false`): Also create an instance profile for the role
- `tags` (map(string), default `{}`)

#### Outputs
- `iac_user_name`
- `iac_user_access_key_id` (sensitive)
- `iac_user_secret_access_key` (sensitive)
- `iac_role_arn`
- `iac_instance_profile_name` (nullable)
- `iac_instance_profile_arn` (nullable)
- `iac_state_encryption_kms_key_arn`

#### Minimal Terragrunt usage
```hcl
terraform {
  source = "../_modules/aws-account-bootstrap"
}

locals {
  account_id = get_env("AWS_ACCOUNT_ID")
  role_name  = "infraAsCode"
  user_name  = "terragrunt"
}

inputs = {
  user_name                 = local.user_name
  role_name                 = local.role_name
  role_max_session_duration = 3600
  permissions_boundary_arn  = null

  # Role policy and KMS key policy
  iam_role_policy_json = file("../_policies/iam/iac-assume-role.json")
  kms_key_policy_json  = templatefile("../_policies/kms/iac-state-key-policy.json", {
    account_id = local.account_id
    role_name  = local.role_name
    user_name  = local.user_name
  })

  # Optional
  create_access_key            = true
  attach_user_assume_role_policy = true
  create_iam_instance_profile  = false

  tags = {
    Project    = "bootstrap"
    Managed_by = "Terragrunt"
  }
}
```

Notes:
- The role’s trust policy allows the created user to assume it by default. If you also need EC2 to assume the role (for instance profiles), set `create_iam_instance_profile = true` and attach additional trust where appropriate in your environment.
- The KMS key policy can be supplied via `kms_key_policy_json`; otherwise a default policy is generated allowing the bootstrap user and role.

