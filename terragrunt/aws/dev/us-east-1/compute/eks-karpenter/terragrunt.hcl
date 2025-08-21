terraform {
  source = "../../../../vendor/modules/tf-aws-eks//modules/karpenter"

  before_hook "helm_registry_logout" {
    commands = ["init", "plan", "apply"]
    execute  = [
      "bash",
      "-lc",
      "HELM_CACHE_HOME='${get_terragrunt_dir()}/.helm/cache' HELM_CONFIG_HOME='${get_terragrunt_dir()}/.helm/config' HELM_REGISTRY_CONFIG='${get_terragrunt_dir()}/.helm/registry.json' sh -lc 'rm -f \"${get_terragrunt_dir()}/.helm/registry.json\" >/dev/null 2>&1 || true; helm registry logout public.ecr.aws >/dev/null 2>&1 || true'"
    ]
  }

  extra_arguments "helm_env" {
    commands = ["init", "plan", "apply"]
    env_vars = {
      HELM_CACHE_HOME      = "${get_terragrunt_dir()}/.helm/cache"
      HELM_CONFIG_HOME     = "${get_terragrunt_dir()}/.helm/config"
      HELM_REGISTRY_CONFIG = "${get_terragrunt_dir()}/.helm/registry.json"
    }
  }
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../../network/vpc"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "kms" {
  config_path = "../../security/kms"
  mock_outputs = {
    wrapper = {
      sqs = {
        key_arn = "arn:aws:kms:us-east-1:111122223333:key/mock"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependencies {
  paths = [
    "../eks",
    "../../network/vpc",
    "../../security/key-pair",
    "../../security/kms"
  ]
}

generate "kubernetes" {
  path      = "_k8s_auth.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  data "aws_eks_cluster" "${local.org_name}-${local.env}" {
    name = "${local.eks_cluster_env_vars.locals.cluster.opsfleet.name}"
  }

  data "aws_eks_cluster_auth" "${local.org_name}-${local.env}" {
    name = "${local.eks_cluster_env_vars.locals.cluster.opsfleet.name}"
  }

  # Initial setup
  provider "kubernetes" {  
    host                   = data.aws_eks_cluster.${local.org_name}-${local.env}.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.${local.org_name}-${local.env}.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.${local.org_name}-${local.env}.name, "--role-arn", "arn:aws:iam::${local.account_id}:role/${get_env("IAM_ASSUME_ROLE", "infraAsCode")}"]
    }
 }

  provider "kubectl" {
    host                   = data.aws_eks_cluster.${local.org_name}-${local.env}.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.${local.org_name}-${local.env}.certificate_authority[0].data)
    load_config_file       = false
    token                  = data.aws_eks_cluster_auth.${local.org_name}-${local.env}.token
  }

  provider "helm" {
    kubernetes = {
      host                   = data.aws_eks_cluster.${local.org_name}-${local.env}.endpoint
      cluster_ca_certificate = base64decode(data.aws_eks_cluster.${local.org_name}-${local.env}.certificate_authority[0].data)
      token                  = data.aws_eks_cluster_auth.${local.org_name}-${local.env}.token
    }
  }
EOF
}

generate "karpenter_values" {
  path      = "_karpenter_values.yaml"
  if_exists = "overwrite_terragrunt"
  contents  = file("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/helm/karpenter/values.yaml")
}

generate "helm_release" {
  path      = "_karpenter_helm.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  provider "aws" {
    region = "us-east-1"
    alias  = "virginia"
    assume_role {
      role_arn = "arn:aws:iam::${local.account_id}:role/${local.role_to_assume}"
    }
  }

  data "aws_ecrpublic_authorization_token" "token" {
    provider = aws.virginia # NOTE: This data source can only be used in the us-east-1 region.
  }
  
  resource "helm_release" "karpenter_crd" {
    namespace           = "kube-system"
    name                = "karpenter-crd"
    repository          = "oci://public.ecr.aws/karpenter"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    chart               = "karpenter-crd"
    version             = var.helm_chart_version
    wait                = var.helm_chart_karpenter_crd_wait

    lifecycle {
      ignore_changes = [repository_username, repository_password]
    }

    depends_on = [
      aws_iam_role.controller,
      aws_iam_role.node,
      aws_iam_role_policy_attachment.controller,
      aws_iam_role_policy_attachment.node,
      aws_iam_role_policy_attachment.node_additional,
      aws_sqs_queue.this,
      aws_sqs_queue_policy.this,
      aws_cloudwatch_event_rule.this,
      aws_cloudwatch_event_target.this,
      aws_eks_pod_identity_association.karpenter,
      aws_eks_access_entry.node,
    ]
  }

  resource "helm_release" "karpenter" {
    namespace           = "kube-system"
    name                = "karpenter"
    repository          = "oci://public.ecr.aws/karpenter"
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    chart               = "karpenter"
    version             = var.helm_chart_version
    wait                = var.helm_chart_karpenter_wait
    skip_crds           = var.helm_chart_karpenter_skip_crds
    reuse_values        = var.helm_chart_karpenter_reuse_values

    # Non-sensitive base values file
    values = [
      file("$${path.module}/_karpenter_values.yaml")
    ]

    lifecycle {
      ignore_changes = [repository_username, repository_password]
    }

    depends_on = [helm_release.karpenter_crd]
  }

  variable "helm_chart_version" {
    description = "Karpenter helm chart version"
    type        = string
    default     = "${local.karpenter_nodegroups_env_vars.locals.helm_chart.karpenter.version}"
  }

  variable "helm_chart_karpenter_crd_wait" {
    description = "Will wait until all resources are in a ready state before marking the release as successful."
    type        = bool
    default     = "${local.karpenter_nodegroups_env_vars.locals.helm_chart.karpenter_crd.wait}"
  }

  variable "helm_chart_karpenter_wait" {
    description = "Will wait until all resources are in a ready state before marking the release as successful."
    type        = bool
    default     = "${local.karpenter_nodegroups_env_vars.locals.helm_chart.karpenter.wait}"
  }

  variable "helm_chart_karpenter_skip_crds" {
    description = "Skip the installation of CRDs. This is useful if you are using a custom version of the CRDs."
    type        = bool
    default     = "${local.karpenter_nodegroups_env_vars.locals.helm_chart.karpenter.skip_crds}"
  }

  variable "helm_chart_karpenter_reuse_values" {
    description = "Reuse the values from the previous release."
    type        = bool
    default     = "${local.karpenter_nodegroups_env_vars.locals.helm_chart.karpenter.reuse_values}"
  }
EOF
}

# Copy CR YAMLs from repo into the module directory so Terraform can read them
generate "karpenter_crs_nodepools_src" {
  path      = "_karpenter_nodepools.yaml"
  if_exists = "overwrite_terragrunt"
  contents  = run_cmd("--terragrunt-quiet", "bash", "-lc", "for f in $(ls -1 ${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/helm/karpenter/nodepools/*.yaml | sort); do [ -f \"$f\" ] || continue; printf -- '---\\n'; cat \"$f\"; printf '\\n'; done")
}

generate "karpenter_crs_ec2nc_src" {
  path      = "_karpenter_ec2nodeclasses.yaml"
  if_exists = "overwrite_terragrunt"
  contents  = run_cmd("--terragrunt-quiet", "bash", "-lc", "for f in $(ls -1 ${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/helm/karpenter/ec2nodeclasses/*.yaml | sort); do [ -f \"$f\" ] || continue; printf -- '---\\n'; cat \"$f\"; printf '\\n'; done")

}

# Generate stable filename indexes to key kubectl_manifest resources deterministically
generate "karpenter_crs" {
  path      = "_karpenter_crs.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  # Stable filenames used as for_each keys to avoid churn
  locals {
    nodepool_filenames = [
      %{ for f in split("\n", run_cmd("--terragrunt-quiet", "bash", "-lc", "ls -1 ${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/helm/karpenter/nodepools/*.yaml | sort | xargs -n1 basename")) ~}
      "${f}"%{ if f != "" },%{ endif }
      %{ endfor ~}
    ]
    ec2nc_filenames = [
      %{ for f in split("\n", run_cmd("--terragrunt-quiet", "bash", "-lc", "ls -1 ${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/helm/karpenter/ec2nodeclasses/*.yaml | sort | xargs -n1 basename")) ~}
      "${f}"%{ if f != "" },%{ endif }
      %{ endfor ~}
    ]
  }
  # Read merged YAMLs that Terragrunt wrote into this module directory
  data "kubectl_file_documents" "nodepools" {
    content = file("$${path.module}/_karpenter_nodepools.yaml")
  }

  data "kubectl_file_documents" "ec2nodeclasses" {
    content = file("$${path.module}/_karpenter_ec2nodeclasses.yaml")
  }

  # Apply CRs only after CRDs and controller are present
  resource "kubectl_manifest" "karpenter_nodepools" {
    for_each   = { for i, d in data.kubectl_file_documents.nodepools.documents : local.nodepool_filenames[i] => d }
    yaml_body  = sensitive(each.value)
    depends_on = [helm_release.karpenter]
  }

  resource "kubectl_manifest" "karpenter_ec2nodeclasses" {
    for_each   = { for i, d in data.kubectl_file_documents.ec2nodeclasses.documents : local.ec2nc_filenames[i] => d }
    yaml_body  = sensitive(each.value)
    depends_on = [helm_release.karpenter]
  }
EOF
}

locals {
  # -----------------------------------------------------------------------------
  # ENVIRONMENT VARIABLES
  # -----------------------------------------------------------------------------
  common_env_vars               = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")
  eks_cluster_env_vars          = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/01-cluster.hcl")
  karpenter_nodegroups_env_vars = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/${local.env}/compute/eks/05-karpenter-nodegroups.hcl")
  region_vars                   = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars                  = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  env             = local.account_vars.locals.environment
  region          = local.region_vars.locals.aws_region
  org_name        = local.common_env_vars.locals.org_name
  account_id      = local.account_vars.locals.aws_account_id
  role_to_assume  = local.account_vars.locals.role_to_assume
}

# ---------------------------------------------------------------------------------------------------------------------
# SUBMODULE PARAMETERS
# These are the variables we have to pass in to use the module.
# Ref: https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  access_entry_type                       = local.karpenter_nodegroups_env_vars.locals.karpenter.access_entry_type
  ami_id_ssm_parameter_arns               = local.karpenter_nodegroups_env_vars.locals.karpenter.ami_id_ssm_parameter_arns
  cluster_ip_family                       = local.eks_cluster_env_vars.locals.cluster.opsfleet.ip_family
  cluster_name                            = local.eks_cluster_env_vars.locals.cluster.opsfleet.name
  create                                  = local.karpenter_nodegroups_env_vars.locals.karpenter.create
  create_access_entry                     = local.karpenter_nodegroups_env_vars.locals.karpenter.create_access_entry
  create_iam_role                         = local.karpenter_nodegroups_env_vars.locals.karpenter.create_iam_role
  create_instance_profile                 = local.karpenter_nodegroups_env_vars.locals.karpenter.create_instance_profile
  create_node_iam_role                    = local.karpenter_nodegroups_env_vars.locals.karpenter.create_node_iam_role
  create_pod_identity_association         = local.karpenter_nodegroups_env_vars.locals.karpenter.create_pod_identity_association
  enable_spot_termination                 = local.karpenter_nodegroups_env_vars.locals.karpenter.enable_spot_termination
  iam_policy_description                  = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_policy_description
  iam_policy_name                         = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_policy_name
  iam_policy_path                         = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_policy_path
  iam_policy_statements                   = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_policy_statements
  iam_policy_use_name_prefix              = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_policy_use_name_prefix
  iam_role_description                    = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_description
  iam_role_max_session_duration           = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_max_session_duration
  iam_role_name                           = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_name
  iam_role_path                           = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_path
  iam_role_permissions_boundary_arn       = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_permissions_boundary_arn
  iam_role_policies                       = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_policies
  iam_role_tags                           = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_tags
  iam_role_use_name_prefix                = local.karpenter_nodegroups_env_vars.locals.karpenter.iam_role_use_name_prefix
  namespace                               = local.karpenter_nodegroups_env_vars.locals.karpenter.namespace
  node_iam_role_additional_policies       = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_additional_policies
  node_iam_role_arn                       = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_arn
  node_iam_role_attach_cni_policy         = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_attach_cni_policy
  node_iam_role_description               = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_description
  node_iam_role_max_session_duration      = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_max_session_duration
  node_iam_role_name                      = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_name
  node_iam_role_path                      = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_path
  node_iam_role_permissions_boundary      = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_permissions_boundary
  node_iam_role_tags                      = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_tags
  node_iam_role_use_name_prefix           = local.karpenter_nodegroups_env_vars.locals.karpenter.node_iam_role_use_name_prefix
  queue_kms_data_key_reuse_period_seconds = local.karpenter_nodegroups_env_vars.locals.karpenter.queue_kms_data_key_reuse_period_seconds
  queue_kms_master_key_id                 = "${flatten([for key, value in dependency.kms.outputs.wrapper : value.key_arn if key == "sqs"])}"
  queue_managed_sse_enabled               = local.karpenter_nodegroups_env_vars.locals.karpenter.queue_managed_sse_enabled
  queue_name                              = local.karpenter_nodegroups_env_vars.locals.karpenter.queue_name
  region                                  = local.karpenter_nodegroups_env_vars.locals.karpenter.region
  rule_name_prefix                        = local.karpenter_nodegroups_env_vars.locals.karpenter.rule_name_prefix
  service_account                         = local.karpenter_nodegroups_env_vars.locals.karpenter.service_account
  tags                                    = local.karpenter_nodegroups_env_vars.locals.karpenter.tags
}