locals {
  common_env_vars   = read_terragrunt_config("${get_path_to_repo_root()}/terragrunt/aws/_inputs/common.hcl")

  org_name        = local.common_env_vars.locals.org_name
  env             = local.common_env_vars.locals.dev_env
  account_id      = local.common_env_vars.locals.dev_account_id
  region          = local.common_env_vars.locals.default_region

  #################################################
  # KMS MODULE VARIABLES
  # Terraform module which creates AWS KMS resources
  # https://registry.terraform.io/modules/terraform-aws-modules/kms/aws/latest
  #################################################
  items = {
    "defaults" = {
      create                  = true
      is_enabled              = false
      enable_default_policy   = false
      multi_region            = false
      deletion_window_in_days = 30
      rotation_period_in_days = 90
    },
    # Encrypt / Decrypt EKS Block storage volumes
    "ec2_ebs" = {
      create                   = true
      is_enabled               = true
      aliases                  = ["${local.org_name}/eks-ebs"]
      enable_key_rotation      = true
      key_usage                = "ENCRYPT_DECRYPT"
      customer_master_key_spec = "SYMMETRIC_DEFAULT"
      description              = "Customer managed key to encrypt EC2 EBS volumes"

      # Custom Policy
      # Key administrators - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators
      policy = templatefile("${get_path_to_repo_root()}/terragrunt/aws/_policies/kms/ebsVolumes.json", {
        account_id               = local.account_id
        key_administrators_role  = "arn:aws:iam::${local.account_id}:role/DevAdminAccessAssumeRole"
        region                   = local.region
      })

      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Role        = "EBSVolumesEncrypt"
          Project     = "${title(local.org_name)}"
        }
      )
    },
    # Encrypt / Decrypt sqs queues. Used for karpenter sqs queue
    "sqs" = {
      create                   = true
      is_enabled               = true
      aliases                  = ["${local.org_name}/sqs"]
      enable_key_rotation      = true
      key_usage                = "ENCRYPT_DECRYPT"
      customer_master_key_spec = "SYMMETRIC_DEFAULT"
      description              = "Customer managed key to encrypt sqs queues. Can be used for karpenter sqs queue."

      # Custom Policy
      # Key administrators - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators
      policy = templatefile("${get_path_to_repo_root()}/terragrunt/aws/_policies/kms/sqsQueues.json", {
        account_id              = local.account_id
        region                  = local.region
        key_administrators_role = "arn:aws:iam::${local.account_id}:role/DevAdminAccessAssumeRole"
      })

      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Role        = "EncryptSqsQueues"
          Project     = "${title(local.org_name)}"
        }
      )
    },
    # Encrypt / Decrypt Cloudwatch logs
    "cloudwatch_logs" = {
      create                   = true
      is_enabled               = true
      aliases                  = ["${local.org_name}/cloudwatch_logs"]
      enable_key_rotation      = true
      key_usage                = "ENCRYPT_DECRYPT"
      customer_master_key_spec = "SYMMETRIC_DEFAULT"
      description              = "Customer managed key to encrypt cloudwatch logs"

      # Custom Policy
      # Key administrators - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators
      policy = templatefile("${get_path_to_repo_root()}/terragrunt/aws/_policies/kms/cloudWatchLogs.json", {
        account_id              = local.account_id
        region                  = local.region
        key_administrators_role = "arn:aws:iam::${local.account_id}:role/DevAdminAccessAssumeRole"
      })

      tags = merge(
        local.common_env_vars.locals.global_tags,
        {
          Environment = local.env
          Role        = "EncryptCloudwatchLogs"
          Project     = "${title(local.org_name)}"
        }
      )
    }
  }
}