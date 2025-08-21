## Terragrunt DRY Patterns and Config Files

This repository follows a layered configuration pattern to keep stacks DRY and predictable.

### root.hcl (pillar root)
- Location: `terragrunt/aws/root.hcl`
- Purpose: Central Terragrunt include for all non-bootstrap stacks.
- Responsibilities:
  - Set `terraform_binary = "tofu"`
  - Configure S3 backend with OpenTofu native lockfile (no DynamoDB)
  - Reference `IAM_ASSUME_ROLE` for role assumption
  - Generate provider stubs (kubernetes/helm/kubectl where applicable)
- Effect: All descendant stacks inherit consistent backend and provider behavior.

### global.hcl (pillar globals)
- Location: `terragrunt/aws/global.hcl`
- Purpose: Shared settings/locals for the pillar (versions, tags, common inputs).
- Typical contents:
  - Provider/module versions (e.g., helm provider version)
  - Global tags map
  - Reusable locals or defaults across the pillar
- Included by: `root.hcl` or directly by stacks if needed.

### common.hcl (input convenience)
- Location: `terragrunt/aws/_inputs/common.hcl`
- Purpose: Central place for organization-wide constants used by environment inputs.
- Typical contents:
  - `org_name`, default region, global tags, dev account id/env name
- Used by: environment-specific input files under `_inputs/dev/...` via `read_terragrunt_config`.

### account.hcl and region.hcl
- `account.hcl` (e.g., `terragrunt/aws/dev/account.hcl`):
  - Captures account-wide identifiers for the environment (e.g., `aws_account_id`, environment name)
  - Enables stacks to reference `local.account_vars.locals...` without duplicating values
- `region.hcl` (e.g., `terragrunt/aws/dev/us-east-1/region.hcl`):
  - Declares the region used by all stacks in that path (`aws_region`)
  - Ensures consistent provider regions, avoiding drift across stacks
- Importance:
  - Separates account identity from region selection
  - Allows multi-region expansions without duplicating account data

### _global (account-level stacks)
- Location: `terragrunt/aws/dev/_global/`
- Purpose: Stacks applied once per account (e.g., account-wide IAM roles, org-wide resources not tied to a single region)
- Orchestration:
  - Run before region-scoped stacks when setting up an account

### _inputs (environment variables as code)
- Environment-specific inputs live under `terragrunt/aws/_inputs/<env>/...`
- Each component (VPC, EKS, Karpenter) reads its inputs via `read_terragrunt_config` to avoid duplication
- Benefits:
  - One place to change a setting, many stacks inherit it
  - Keeps stack `terragrunt.hcl` focused on wiring and dependencies

### Dependencies and mocks
- Use `dependency` blocks to read outputs from upstream stacks
- For unapplied dependencies, add `mock_outputs` (and restrict to init/validate/plan) to keep plans working while preserving correct wiring

### Why this matters
- DRY: Reduce copy/paste and config drift across stacks
- Observability: Clear separation of concerns (account vs region vs component)
- Safety: Consistent backends and providers across all stacks, enforced centrally

### Command scope
- Single stack: run commands inside that stack directory
- Region scope: run `terragrunt run-all` from the region directory
- Account scope: run `terragrunt run-all` from `terragrunt/aws`
