## 06. eks-karpenter

Requires VPN connected (private EKS endpoint). See 04-OpenVPN.

### Deploy
```bash
cd terragrunt/aws/dev/us-east-1/compute/eks-karpenter
terragrunt init -upgrade
terragrunt plan
terragrunt apply -auto-approve
```

What happens:
- Installs CRDs first, then the Karpenter chart
- Applies NodePools and EC2NodeClasses after the chart
- Reads Helm values from a generated file and hides them in plan

### Where to edit Helm values
- Base values file (source of truth in repo):
  - `terragrunt/aws/_inputs/dev/compute/eks/helm/karpenter/values.yaml`
- At apply time Terragrunt copies this file into the module as `_karpenter_values.yaml` and the Helm provider reads it.
- Notes:
  - Values are passed as `values = [ file("${path.module}/_karpenter_values.yaml") ]`; we often wrap in `sensitive(...)` to suppress stdout noise.
  - Reuse previous values is enabled via `reuse_values` (see below).

Control chart settings (version, waits, reuse):
- Edit: `terragrunt/aws/_inputs/dev/compute/eks/05-karpenter-nodegroups.hcl`
  - `locals.helm_chart.karpenter.version`
  - `locals.helm_chart.karpenter_crd.wait`
  - `locals.helm_chart.karpenter.wait`
  - `locals.helm_chart.karpenter.skip_crds`
  - `locals.helm_chart.karpenter.reuse_values`

### Add or change NodePools
- Location (source files in repo):
  - `terragrunt/aws/_inputs/dev/compute/eks/helm/karpenter/nodepools/*.yaml`
- Create a new file, e.g. `amd64-batch.yaml` with kind `NodePool` and apiVersion `karpenter.sh/v1`.
- Ensure `spec.template.spec.nodeClassRef.name` matches an existing EC2NodeClass (see below), and set requirements (arch, capacity-type, families, zones) and disruption as needed.
- Apply:
```bash
cd terragrunt/aws/dev/us-east-1/compute/eks-karpenter
terragrunt plan && terragrunt apply -auto-approve
```
- Implementation details:
  - Terragrunt concatenates all `nodepools/*.yaml` into `_karpenter_nodepools.yaml` in a stable, sorted order.
  - Terraform keys each `kubectl_manifest` by the source filename (deterministic), so changes to content update in place; renaming a file recreates the resource.

### Add or change EC2NodeClasses
- Location (source files in repo):
  - `terragrunt/aws/_inputs/dev/compute/eks/helm/karpenter/ec2nodeclasses/*.yaml`
- Create a new file, e.g. `arm64-cost.yaml` with kind `EC2NodeClass` and apiVersion `karpenter.k8s.aws/v1`.
- Configure at minimum:
  - `amiFamily` (e.g., `Bottlerocket`)
  - Subnet and security group selectors (tags from your VPC/EKS module)
  - Optional kubelet/metadata/tags per your standards
- Apply:
```bash
cd terragrunt/aws/dev/us-east-1/compute/eks-karpenter
terragrunt plan && terragrunt apply -auto-approve
```
- Implementation details:
  - Files are concatenated into `_karpenter_ec2nodeclasses.yaml` in sorted order and applied with keys derived from filenames (deterministic).

### Remove a NodePool or EC2NodeClass
- Delete the corresponding YAML file from the `nodepools/` or `ec2nodeclasses/` directory.
- Run plan/apply; Terraform will destroy the manifest keyed by that filename.

### Tips & troubleshooting
- Private endpoint: keep VPN connected for plan/apply, or run inside the VPC (see Troubleshooting: Private EKS connectivity).
- Plan noise for Helm values: enable `reuse_values` and/or wrap values with `sensitive(file(...))`.
- Prevent churn for CRs: we already use stable, filename-based keys and sorted inputs to avoid perpetual updates.
- Public ECR: no login is required for `oci://public.ecr.aws/karpenter`; do not set repository credentials.
