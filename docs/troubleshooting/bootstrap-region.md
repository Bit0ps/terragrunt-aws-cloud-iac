## Bootstrap region/account resolution

Symptoms:
- `Not enough function arguments` (from `trim(...)`) or `EnvVarNotFoundError` for `AWS_REGION` / `AWS_ACCOUNT_ID`.
- Bootstrap fails to detect region/account.

How it works in this repo:
- Account ID is detected via: `aws sts get-caller-identity --query Account --output text`.
- Region is resolved in order: `AWS_REGION`, `AWS_DEFAULT_REGION`, then parsed from `aws configure list --json`. Fallback: `us-east-1`.

Fixes:
1) Ensure AWS CLI is authenticated before bootstrap.
```bash
aws sts get-caller-identity
```
2) Ensure a default region is set or export one:
```bash
aws configure set region us-east-1
# or
export AWS_REGION=us-east-1
```
3) If you lack jq, install it (used for parsing CLI JSON output).
```bash
brew install jq # macOS
```
4) If running with profiles, set `AWS_PROFILE` before `terragrunt plan`.
```bash
export AWS_PROFILE=your-profile
```
5) As a last resort, export both explicitly:
```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1
```

Notes:
- The bootstrap uses local state; S3/KMS settings come later in downstream stacks.
- If using SSO/role-based profiles, make sure `aws sts get-caller-identity` succeeds within that profile first.
