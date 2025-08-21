# Modules in the account _global folder don't live in any specific AWS region, but you still have to send the API calls
# to _some_ AWS region, so here we use the default region for those API calls.
locals {
  aws_region = read_terragrunt_config(find_in_parent_folders("global.hcl")).locals.default_region
}