## 03. Networking (VPC)

1) Initialize backend and deploy VPC:
```bash
cd terragrunt/aws/dev/us-east-1/network/vpc
: "${TF_IAC_STATE_KMS_KEY_ARN:?Set TF_IAC_STATE_KMS_KEY_ARN}"
terragrunt backend bootstrap
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
```

2) Subnets for EKS
- Private and public subnets use /20 masks (see `_inputs/dev/network/vpc.hcl`).
- Tags include discovery keys for EKS/Karpenter.
