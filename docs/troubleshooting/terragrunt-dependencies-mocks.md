## Terragrunt dependencies and mocks

Errors:
- "Unknown variable dependency" or missing dependency outputs during plan.

Guidelines:
- Use `dependency` blocks for upstream outputs; in unapplied plans, add `mock_outputs` and restrict to init/validate/plan.
```hcl
dependency "vpc" {
  config_path = "../../network/vpc"
  mock_outputs = { vpc_id = "vpc-00000000000000000" }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}
```
- If you don’t need outputs, prefer `dependencies { paths = [...] }` to enforce order only.
- Avoid `dependency` in shared root files (brittle); pass outputs via inputs or env when necessary.
