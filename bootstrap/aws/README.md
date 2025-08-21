## Bootstrap (Terragrunt + OpenTofu)

This folder contains a standalone Terragrunt configuration to bootstrap a fresh AWS account for use with Terragrunt/OpenTofu. It creates:

- IAM user: `terragrunt` (optional access key)
- IAM role: `infraAsCode` (assumable by the user)
- IAM policy: attached to the role (from JSON template)
- KMS key: for S3 backend SSE-KMS encryption (policy from JSON template)

The S3 state bucket is not created here; Terragrunt will auto-create it later via `terragrunt backend bootstrap` in your real stacks.

### Prerequisites

- OpenTofu installed (`tofu` in PATH)
- Terragrunt installed (`terragrunt` in PATH)
- AWS CLI installed (`aws` in PATH)
- jq installed (`jq` in PATH) — required by the credential prefetch script
- Optionally, aws-vault installed (`aws-vault` in PATH) to securely manage credentials and MFA
- AWS credentials exported (root/break-glass or admin) with permissions to create IAM and KMS resources

### Environment and automatic discovery

- Account id and region are resolved automatically by the bootstrap config:
  - Account id via `aws sts get-caller-identity`
  - Region via, in order: `AWS_REGION`, `AWS_DEFAULT_REGION`, or your default CLI profile

Important: you must have AWS credentials configured before running bootstrap so that the CLI can resolve the region. If you do not have a default region configured (e.g., via `aws configure`), set `AWS_REGION` explicitly or you may get an error.

Ways to provide credentials (choose one):
- Static creds:
  - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, (optional) `AWS_SESSION_TOKEN`
- AWS profile:
  - `AWS_PROFILE` (must be configured in `~/.aws/config`/`~/.aws/credentials`)

### Policies used as inputs

- IAM role policy (assume your desired permissions):
  - `terragrunt/aws/_policies/iam/iac-assume-role.json`
- KMS key policy (templated with your env):
  - `terragrunt/aws/_policies/kms/iac-state-key-policy.json`

Terragrunt uses `templatefile` to inject `account_id`, `role_name`, and `user_name` into the KMS policy.

### Fetch credentials (MFA or role)

If your initial access requires MFA or role assumption, you can pre-fetch session credentials using the helper script. The script supports either providing an MFA device serial ARN directly, or building it from `--mfa-device-name` plus `--account-id` (or `AWS_ACCOUNT_ID` env). You can also control token validity with `--duration-seconds`.

```bash
cd ../_scripts

# Option 0: Use the configured profile as-is (no extra STS call). Recommended when your profile already chains role/SSO
eval "$(./aws_prefetch_creds.sh profile \
  --profile "${AWS_PROFILE}")"

# Option A.1: Get a session token with MFA for an IAM user (using MFA serial ARN)
eval "$(./aws_prefetch_creds.sh session-token \
  --mfa-serial arn:aws:iam::<AWS_ACCOUNT_ID>:mfa/<MFA_DEVICE_NAME> \
  --mfa-code 123456 \
  --duration-seconds 3600)"

# Option A.2: Same, using MFA device name (script builds the ARN). You can omit --account-id if AWS_ACCOUNT_ID is exported
eval "$(./aws_prefetch_creds.sh session-token \
  --mfa-device-name <MFA_DEVICE_NAME> \
  --account-id ${AWS_ACCOUNT_ID} \
  --mfa-code 123456 \
  --duration-seconds 3600)"

# Option B: Assume an admin role (with or without MFA)
eval "$(./aws_prefetch_creds.sh assume-role \
  --role-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ASSUME_ROLE> \
  --session-name iac-bootstrap \
  --duration-seconds 3600)"

# Or include MFA if required (using MFA serial ARN)
eval "$(./aws_prefetch_creds.sh assume-role \
  --role-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ASSUME_ROLE> \
  --session-name iac-bootstrap \
  --mfa-serial arn:aws:iam::<AWS_ACCOUNT_ID>:mfa/<MFA_DEVICE_NAME> \
  --mfa-code 123456 \
  --duration-seconds 3600)"

# Or include MFA using device name (script builds the ARN). You can omit --account-id if AWS_ACCOUNT_ID is exported
eval "$(./aws_prefetch_creds.sh assume-role \
  --role-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ASSUME_ROLE> \
  --session-name iac-bootstrap \
  --mfa-device-name <MFA_DEVICE_NAME> \
  --account-id ${AWS_ACCOUNT_ID} \
  --mfa-code 123456 \
  --duration-seconds 3600)"
```

### Credential helper commands

- `profile`:
  - Exports credentials resolved by your AWS profile (supports SSO, role chaining, MFA managed by the profile).
  - Example:
    ```bash
    eval "$(../_scripts/aws_prefetch_creds.sh profile --profile "${AWS_PROFILE}")"
    ```
- `session-token`:
  - Obtains STS session tokens for an IAM user. Use when your profile is a plain IAM user. Supports MFA.
  - Common flags:
    - `--profile <name>`: source profile to use
    - `--mfa-serial <arn>` OR `--mfa-device-name <name>` with `--account-id <id>`
    - `--mfa-code <totp>` (required when MFA serial is used)
    - `--duration-seconds <n>` (default 3600)
    - `--no-mfa` (only if your policy allows GetSessionToken without MFA)
- `assume-role`:
  - Assumes a role and emits temporary credentials. Works with SSO/role profiles too.
  - Common flags:
    - `--profile <name>`: source profile to use; if it has `role_arn`, it will be used automatically
    - `--role-arn <arn>` (optional if in profile)
    - `--session-name <name>` (required)
    - `--external-id <id>`
    - `--mfa-serial <arn>` OR `--mfa-device-name <name>` with `--account-id <id>`
    - `--mfa-code <totp>` (required when MFA serial is in effect)
    - `--duration-seconds <n>` (default 3600)
    - `--no-mfa` (skip MFA entirely)

### Help

- Show global usage:
  ```bash
  ../_scripts/aws_prefetch_creds.sh --help
  ```
- Show mode-specific help (pass `--help` after the mode):
  ```bash
  ../_scripts/aws_prefetch_creds.sh assume-role --help
  ../_scripts/aws_prefetch_creds.sh session-token --help
  ../_scripts/aws_prefetch_creds.sh profile --help
  ```

#### Optional: Use aws-vault

If you use `aws-vault`, you can securely fetch short-lived credentials (with MFA and/or role assumption) and execute Terragrunt:

Prereqs:
- Configure a profile in `~/.aws/config` (example with role + MFA):

```ini
[profile iac-bootstrap]
region = us-east-1
mfa_serial = arn:aws:iam::<AWS_ACCOUNT_ID>:mfa/<MFA_DEVICE_NAME>
role_arn = arn:aws:iam::<AWS_ACCOUNT_ID>:role/<ASSUME_ROLE>
source_profile = default
```

Usage examples:

```bash
# Simple exec with profile-managed role/MFA
aws-vault exec iac-bootstrap -- bash -c '
  export AWS_ACCOUNT_ID=<TARGET_ACCOUNT_ID>
  export AWS_REGION=us-east-1
  cd terragrunt/aws/bootstrap && terragrunt init && terragrunt apply -auto-approve
'

# Or just open a shell and run commands manually
aws-vault exec iac-bootstrap -- bash
export AWS_ACCOUNT_ID=<TARGET_ACCOUNT_ID>
export AWS_REGION=us-east-1
cd terragrunt/aws/bootstrap
terragrunt init
terragrunt apply -auto-approve
```

You can also use `aws-vault` without role settings in the profile; it will still provide short-lived creds and prompt for MFA if configured.

### Run

From this directory:

```bash
cd terragrunt/aws/bootstrap

# Ensure region can be resolved (either export AWS_REGION or set a default via `aws configure`)

# Init and apply
terragrunt init
terragrunt apply -auto-approve
```

### Outputs

- `bootstrap_user_access_key_id` and `bootstrap_user_secret_access_key` (if `create_access_key = true`)
- `iac_role_arn`
- `kms_key_arn`

Export KMS key for S3 backend (used by Terragrunt root state):

```bash
export TF_IAC_STATE_KMS_KEY_ARN=$(terragrunt output -raw kms_key_arn)
```

### Next steps (state bucket)

- In a downstream stack (e.g., under `terragrunt/aws/dev/...`), ensure your `remote_state` S3 config has `use_lockfile = true` and optionally `kms_key_id = env.TF_IAC_STATE_KMS_KEY_ARN`.
- Then run:

```bash
terragrunt backend bootstrap
```

This will auto-create the S3 bucket. After that, you may attach a stricter bucket policy (TLS-only, account-only) if desired.

### Customization

You can customize via inputs in `terragrunt.hcl`:

- `user_name`, `role_name`
- `create_access_key`, `attach_user_assume_role_policy`
- `role_max_session_duration`, `permissions_boundary_arn`
- `kms_key_alias`
- `create_iam_instance_profile`

Update the policy templates to match your organization’s standards.