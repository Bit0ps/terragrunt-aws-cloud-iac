## Repo Layout Reference

- terragrunt/aws/_inputs: environment-specific variables per component
- terragrunt/aws/_modules: custom Terraform modules
- terragrunt/aws/_policies: IAM and KMS policy JSON
- terragrunt/aws/_scripts: helper scripts (credentials)
- bootstrap/aws: one-shot bootstrap stack
- terragrunt/aws/dev/_global: account-level global stacks (e.g., IAM roles, IAM policies)
- terragrunt/aws/dev/us-east-1: region-scoped stacks
- docs/: getting-started, architecture, references

### Region-scoped stacks (example: `terragrunt/aws/dev/us-east-1`)

- network/vpc: VPC and subnets
- security/kms: KMS keys for logs (CloudWatch), EBS, SQS
- security/security-groups/openvpn: Security group for OpenVPN EC2
- security/key-pair: EC2 key pair(s)
- compute/ec2: OpenVPN EC2 instance
- compute/eks: EKS cluster
- compute/eks-karpenter: Karpenter (CRDs → Helm → CRs)
