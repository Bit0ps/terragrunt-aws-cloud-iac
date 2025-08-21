## 01. Credentials

Prereqs: OpenTofu, Terragrunt, AWS CLI, jq.

- Using an AWS profile (recommended):
```bash
export AWS_PROFILE=opsfleet-dev
aws sts get-caller-identity
```

- Using the helper (exports env vars; supports MFA/assume/profile):
```bash
cd terragrunt/aws/_scripts
# Use your configured profile
eval "$(./aws_prefetch_creds.sh profile --profile opsfleet-dev)"
```

- With aws-vault (optional):
```bash
aws-vault exec opsfleet-dev -- terragrunt plan
```

Notes:
- Ensure your role assumption path matches `IAM_ASSUME_ROLE` (default: infraAsCode).
- For MFA-enabled roles, prefer the helper or aws-vault to obtain session creds.
