## Terragrunt Infrastructure Docs

### Sections
- Getting Started: [getting-started/_index.md](getting-started/_index.md)
  - [01-credentials.md](getting-started/01-credentials.md)
  - [02-bootstrap.md](getting-started/02-bootstrap.md)
  - [03-networking.md](getting-started/03-networking.md)
  - [04-openvpn.md](getting-started/04-openvpn.md)
  - [05-eks.md](getting-started/05-eks.md)
  - [06-eks-karpenter.md](getting-started/06-eks-karpenter.md)
  - [07-post-deploy.md](getting-started/07-post-deploy.md)
- Architecture: [architecture/_index.md](architecture/_index.md)
  - Diagrams: [architecture/diagrams/](architecture/diagrams/)
- References:
  - [repo-layout.md](references/repo-layout.md)
  - [cli-cheatsheet.md](references/cli-cheatsheet.md)
  - [terragrunt-patterns.md](references/terragrunt-patterns.md)
- Troubleshooting: [troubleshooting/_index.md](troubleshooting/_index.md)
  - [connectivity-private-eks.md](troubleshooting/connectivity-private-eks.md)
  - [kubectl-manifest-churn.md](troubleshooting/kubectl-manifest-churn.md)
  - [terragrunt-dependencies-mocks.md](troubleshooting/terragrunt-dependencies-mocks.md)
  - [paths-terragrunt-cache.md](troubleshooting/paths-terragrunt-cache.md)
  - [bootstrap-region.md](troubleshooting/bootstrap-region.md)

### Scope
- AWS IaC with OpenTofu + Terragrunt
- S3 remote state with KMS and native locking
- Private EKS cluster and Karpenter provisioning

### Conventions
- Run Terragrunt commands from stack directories unless noted
- Use region-level `run-all` for orchestrated applies
- Prefer environment variables over in-file secrets
