## Paths and .terragrunt-cache

Problem:
- Terraform runs from the generated module in `.terragrunt-cache`, so `file()` cannot read paths outside the module source.

Solutions:
- Use a Terragrunt `generate` block to copy needed files into the module directory (e.g., `_karpenter_values.yaml`).
- Or use `templatefile()` with templates generated into the module directory.
- Avoid direct `file()` calls to repo paths from within Terraform; instead, stage the files via Terragrunt.
