locals {
  # Enter a unique name prefix to set for all resources created in your accounts, e.g., your org name.
  org_name    = "opsfleet"

  # Enter the default AWS region, the same as where the terraform state S3 bucket is currently provisioned.
  default_region = "us-east-1"

  # An accounts map to conveniently store all account IDs.
  # Centrally define all the AWS account IDs. We use JSON so that it can be readily parsed outside of Terraform.
 # accounts = jsondecode(file("accounts.json"))

  # Providers versions
  aws_provider_version        = "~> 6.0"
  kubectl_provider_version    = "~> 2.0"
  helm_provider_version       = "~> 3.0"

  tags = {
    Organization = "${title(local.org_name)}"
    OpenTofu     = "true"
    Terragrunt   = "true"
  }
}