## 05. EKS

Deploy the EKS cluster

```bash
cd terragrunt/aws/dev/us-east-1/compute/eks
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
```

Notes:
- Provider auth: helm/kubectl providers authenticate via AWS EKS token exec.
