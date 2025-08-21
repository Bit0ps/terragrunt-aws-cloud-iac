## Architecture Overview

- OpenTofu + Terragrunt with S3 remote state and KMS
- Private EKS cluster (endpoint private), access via OpenVPN EC2
- Karpenter integration (IAM, SQS/EventBridge, CRDs/Helm/CRs)

Diagrams:
- See `docs/architecture/diagrams/` for Mermaid sources.
- Suggested: infra-overview.mmd, networking-private-eks.mmd, eks-karpenter-flow.mmd
