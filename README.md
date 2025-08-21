## AWS InfrastructureAsCode (Terragrunt + OpenTofu)

IaC for AWS using OpenTofu with Terragrunt. S3 remote state with native lockfile, DRY inputs, and a private EKS cluster with Karpenter.

### Prerequisites
- OpenTofu (`tofu`), Terragrunt (`terragrunt`), AWS CLI (`aws`), jq
- Optional: aws-vault

### Quickstart
1) Credentials and profiles: see Getting Started 01 (links below)
2) Bootstrap (one-time): create IAM user/role + KMS key
```bash
cd bootstrap/aws
terragrunt init
terragrunt apply -auto-approve
# optional: export KMS ARN for backend bootstrap later
export TF_IAC_STATE_KMS_KEY_ARN=$(terragrunt output -raw kms_key_arn)
```
3) Deploy main stacks at once (exclude eks-karpenter initially)
```bash
cd terragrunt/aws
terragrunt init --all -upgrade
terragrunt plan --all --terragrunt-exclude-dir 'terragrunt/aws/dev/us-east-1/compute/eks-karpenter'

# if there are no errors
terragrunt apply --all -auto-approve --terragrunt-exclude-dir 'terragrunt/aws/dev/us-east-1/compute/eks-karpenter'
```
4) Connect to private EKS via OpenVPN (see Getting Started 04)
5) Deploy eks-karpenter
```bash
cd terragrunt/aws/dev/us-east-1/compute/eks-karpenter
terragrunt plan && terragrunt apply -auto-approve
```

Full step-by-step: see docs/getting-started/ (links below).

### Directory structure (key paths)
```
infra/
  terragrunt/
    aws/
      _inputs/                 # Environment inputs (dev/...)
        dev/
          compute/
            eks/               # EKS inputs (incl. v21 migration-aligned)
            eks/helm/karpenter # Karpenter values, NodePools, EC2NodeClasses
          network/
            vpc.hcl            # VPC CIDRs (/20 for EKS), tags
      _modules/
        aws-account-bootstrap/ # Bootstrap user/role/policy/KMS
      _policies/
        iam/                   # IAC role policy (EKS/EC2/etc.)
        kms/                   # Key policies (ViaService/CallerAccount)
      _scripts/
        aws_prefetch_creds.sh  # Credential helper (MFA/assume/profile)
      root.hcl                 # Root include (S3 backend, role assume, tofu)
      Terrafile                # Module vendoring map (vendor/)
      dev/
        _global/               # AWS Global stacks (IAM)
        account.hcl            # Dev account settings
        us-east-1/
          region.hcl
          network/vpc/         # VPC stack
          security/kms/        # KMS keys (CloudWatch, EBS, SQS)
          security/security-groups/openvpn/ # OpenVPN security group
          security/key-pair/   # EC2 key pair(s)
          compute/ec2/         # EC2: OpenVPN instance
          compute/eks/         # EKS stack
          compute/eks-karpenter/ # Karpenter stack (CRDs→Helm→CRs)
  docs/
    getting-started/           # Step-by-step guides (credentials→Karpenter)
    architecture/              # Overview + diagrams
    references/                # Repo layout, CLI, version matrix
  bootstrap/
    aws/                       # Standalone one-shot bootstrap stack
```

### Environment variables (Terragrunt + OpenTofu)
- Auth (one of):
  - `AWS_PROFILE` (recommended), or `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- Region/account:
  - `AWS_REGION` (required for bootstrap and stacks)
  - `AWS_ACCOUNT_ID_DEV` (used by `dev/account.hcl`; derive via `aws sts get-caller-identity`)
- Backend/state:
  - `TF_IAC_STATE_KMS_KEY_ARN` (required when running `terragrunt backend bootstrap` from stacks)
- Role assumption:
  - `IAM_ASSUME_ROLE` (default `infraAsCode`) used by providers/exec auth
- Optional knobs:
  - `KUBECONFIG`, `KUBE_CONTEXT` (if using local kubectl context outside the generated providers)

### Terragrunt quick commands
- One stack (run from stack dir):
```bash
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
```

- Region scope (all stacks under a region, with deps):
```bash
cd terragrunt/aws/dev/us-east-1
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
```

- Account scope (everything under aws/dev):
```bash
cd terragrunt/aws/dev
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
```

- Global scope (everything under aws):
```bash
cd terragrunt/aws
terragrunt init --all -upgrade
terragrunt plan --all
terragrunt apply --all -auto-approve
```

- Include/exclude subsets:
```bash
terragrunt plan --all --terragrunt-include-dir 'terragrunt/aws/dev/us-east-1/network/vpc'
terragrunt apply --all -auto-approve --terragrunt-exclude-dir 'terragrunt/aws/dev/us-east-1/compute/eks-karpenter'
```

- Destroy:
```bash
terragrunt destroy -auto-approve
terragrunt destroy --all -auto-approve
```

### Documentation
- Getting Started (step-by-step): [docs/getting-started/_index.md](docs/getting-started/_index.md)
  - 01 Credentials: [docs/getting-started/01-credentials.md](docs/getting-started/01-credentials.md)
  - 02 Bootstrap: [docs/getting-started/02-bootstrap.md](docs/getting-started/02-bootstrap.md)
  - 03 Networking (VPC): [docs/getting-started/03-networking.md](docs/getting-started/03-networking.md)
  - 04 OpenVPN (private access): [docs/getting-started/04-openvpn.md](docs/getting-started/04-openvpn.md)
  - 05 EKS: [docs/getting-started/05-eks.md](docs/getting-started/05-eks.md)
  - 06 eks-karpenter: [docs/getting-started/06-eks-karpenter.md](docs/getting-started/06-eks-karpenter.md)
  - 07 Post-deploy: [docs/getting-started/07-post-deploy.md](docs/getting-started/07-post-deploy.md)
- Architecture: [docs/architecture/_index.md](docs/architecture/_index.md) (diagrams in [docs/architecture/diagrams/](docs/architecture/diagrams/))
- References: repo layout and CLI: [docs/references/repo-layout.md](docs/references/repo-layout.md), [docs/references/cli-cheatsheet.md](docs/references/cli-cheatsheet.md)

Details on DRY patterns and config files: [docs/references/terragrunt-patterns.md](docs/references/terragrunt-patterns.md)

### Troubleshooting
- Private EKS connectivity: [docs/troubleshooting/connectivity-private-eks.md](docs/troubleshooting/connectivity-private-eks.md)
- kubectl_manifest churn: [docs/troubleshooting/kubectl-manifest-churn.md](docs/troubleshooting/kubectl-manifest-churn.md)
- Terragrunt dependencies and mocks: [docs/troubleshooting/terragrunt-dependencies-mocks.md](docs/troubleshooting/terragrunt-dependencies-mocks.md)
- Paths with .terragrunt-cache: [docs/troubleshooting/paths-terragrunt-cache.md](docs/troubleshooting/paths-terragrunt-cache.md)
- Bootstrap region/account resolution: [docs/troubleshooting/bootstrap-region.md](docs/troubleshooting/bootstrap-region.md)