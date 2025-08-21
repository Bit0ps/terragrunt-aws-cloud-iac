## 02. Bootstrap (fresh account)

Creates IAM user `terragrunt`, IAM role `infraAsCode`, and a KMS key for S3 state.

1) Credentials ready (see 01-credentials).
2) Run bootstrap (account id and region are auto-detected; ensure credentials and a default region are configured or export AWS_REGION):
```bash
cd bootstrap/aws
terragrunt init
terragrunt apply -auto-approve
```
3) Export KMS ARN for downstream stacks:
```bash
export TF_IAC_STATE_KMS_KEY_ARN=$(terragrunt output -raw kms_key_arn)
```
4) Switch to the new user/role (profile or helper).
