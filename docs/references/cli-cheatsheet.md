## CLI Cheatsheet

### Per-stack
Run from: the specific stack directory (e.g., `terragrunt/aws/dev/us-east-1/network/vpc`)
```bash
cd terragrunt/aws/dev/us-east-1/network/vpc
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
terragrunt destroy --all -auto-approve
```

### Region/account (run-all)
Run from: a region directory (for region scope) or `terragrunt/aws` (for account scope)
```bash
# Region scope
cd terragrunt/aws/dev/us-east-1
terragrunt init --all -upgrade
terragrunt plan --all 
terragrunt apply --all  -auto-approve
terragrunt destroy --all -auto-approve

# Account scope (all stacks under aws/dev)
cd terragrunt/aws/dev
terragrunt init --all -upgrade
terragrunt plan --all 
terragrunt apply --all  -auto-approve
terragrunt destroy --all -auto-approve

# Global scope (all available stack except bootstrap under terragrunt/aws)
cd terragrunt/aws
terragrunt plan --all
terragrunt apply --all -auto-approve
terragrunt destroy --all -auto-approve
```

### Include/exclude
Run from: region or account directory (`terragrunt/aws/dev/us-east-1` or `terragrunt/aws`)
```bash
cd terragrunt/aws/dev/us-east-1
terragrunt plan --all --terragrunt-include-dir 'terragrunt/aws/dev/us-east-1/network/vpc'
terragrunt apply --all -auto-approve --terragrunt-exclude-dir 'terragrunt/aws/dev/us-east-1/compute/eks-karpenter'
```

### Useful flags
```bash
--terragrunt-parallelism 4 --terragrunt-log-level error --terragrunt-non-interactive
```

### More Terragrunt examples
Run from: region or account directory unless noted
```bash
# Only changed stacks (ignore dep errors during planning)
cd terragrunt/aws/dev/us-east-1
terragrunt plan --all --terragrunt-ignore-dependency-errors
terragrunt apply --all -auto-approve --terragrunt-include-external-dependencies

# Validate across a scope
cd terragrunt/aws
terragrunt init --all -upgrade
terragrunt validate --all

# Refresh state
cd terragrunt/aws/dev/us-east-1/network/vpc
terragrunt refresh
cd terragrunt/aws/dev/us-east-1
terragrunt refresh --all

# Dependency graph (requires graphviz)
cd terragrunt/aws
terragrunt graph-dependencies | dot -Tpng > deps.png

# Backend bootstrap if bucket is missing
cd terragrunt/aws/dev/us-east-1/network/vpc
terragrunt backend bootstrap
```

---

## Helper script: aws_prefetch_creds.sh
Path: `terragrunt/aws/_scripts/aws_prefetch_creds.sh`

Requires: `aws`, `jq`

Usage:
```bash

# Export creds from an existing profile (handles SSO/role chaining)
cd terragrunt/aws/_scripts
./aws_prefetch_creds.sh profile --profile <source_profile>

# Get session token for IAM user (MFA)
cd terragrunt/aws/_scripts
./aws_prefetch_creds.sh session-token \
  [--profile <source_profile>] \
  [--mfa-serial <MFA_DEVICE_ARN> | --mfa-device-name <MFA_DEVICE_NAME> [--account-id <ACCOUNT_ID>]] \
  [--mfa-code <MFA_TOTP_CODE>] \
  [--no-mfa] \
  [--duration-seconds 3600]

# Assume role (optionally MFA / external id)
cd terragrunt/aws/_scripts
./aws_prefetch_creds.sh assume-role \
  [--profile <source_profile>] \
  [--role-arn <ROLE_ARN>] \
  --session-name <SESSION_NAME> \
  [--external-id <EXTERNAL_ID>] \
  [--mfa-serial <MFA_DEVICE_ARN> | --mfa-device-name <MFA_DEVICE_NAME> [--account-id <ACCOUNT_ID>]] \
  [--mfa-code <MFA_TOTP_CODE>] \
  [--no-mfa] \
  [--duration-seconds 3600]
```

Flags:
- `--profile <name>`: AWS profile to source credentials from
- `--mfa-serial <arn>`: full ARN of MFA device
- `--mfa-device-name <name>`: short device name; requires `--account-id` or `AWS_ACCOUNT_ID`
- `--account-id <id>`: 12-digit account id, used with `--mfa-device-name`
- `--mfa-code <totp>`: 6-digit MFA code
- `--no-mfa`: bypass MFA for flows where policy allows it
- `--role-arn <arn>`: role to assume (assume-role mode)
- `--session-name <name>`: session name (assume-role mode, required)
- `--external-id <id>`: external id (assume-role only)
- `--duration-seconds <n>`: session duration in seconds
- `-h|--help`: show usage

Tips:
- Load into your shell by using eval:
```bash
eval "$(./aws_prefetch_creds.sh profile --profile <USER_PROFILE>)"
```
- Avoid `session-token` with assumed-role/SSO profiles; prefer `assume-role`.
