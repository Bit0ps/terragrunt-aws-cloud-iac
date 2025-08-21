data "aws_caller_identity" "current" {}

resource "aws_iam_user" "bootstrap" {
  name                 = var.user_name
  force_destroy        = true
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_access_key" "bootstrap" {
  count = var.create_access_key ? 1 : 0
  user  = aws_iam_user.bootstrap.name
}

data "aws_iam_policy_document" "assume_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.bootstrap.arn]
    }
  }
}

resource "aws_iam_role" "iac" {
  name                  = var.role_name
  assume_role_policy    = data.aws_iam_policy_document.assume_role_trust.json
  force_detach_policies = true
  max_session_duration  = var.role_max_session_duration
  permissions_boundary  = var.permissions_boundary_arn
  tags                  = var.tags
}

resource "aws_iam_policy" "iac_inline" {
  name        = "${var.role_name}Policy"
  description = "Inline policy for IaC role"
  policy      = var.iam_role_policy_json
}

resource "aws_iam_role_policy_attachment" "iac_attach" {
  role       = aws_iam_role.iac.name
  policy_arn = aws_iam_policy.iac_inline.arn
}

# Optionally attach an inline policy to the bootstrap user to allow assuming the role
data "aws_iam_policy_document" "user_assume_role" {
  count = var.attach_user_assume_role_policy ? 1 : 0
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.iac.arn]
  }
}

resource "aws_iam_user_policy" "bootstrap_assume_role" {
  count  = var.attach_user_assume_role_policy ? 1 : 0
  name   = "iacBootstrapAssumeRole"
  user   = aws_iam_user.bootstrap.name
  policy = data.aws_iam_policy_document.user_assume_role[0].json
}

locals {
  default_kms_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "EnableRootPermissions",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "AllowRoleUseOfKey",
        Effect    = "Allow",
        Principal = { AWS = aws_iam_role.iac.arn },
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:ListAliases"
        ],
        Resource = "*"
      },
      {
        Sid       = "AllowUserUseOfKey",
        Effect    = "Allow",
        Principal = { AWS = aws_iam_user.bootstrap.arn },
        Action = [
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:ListAliases"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_key" "state" {
  description             = "KMS key for OpenTofu/Terragrunt state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = coalesce(var.kms_key_policy_json, local.default_kms_policy)
  tags                    = var.tags
}

resource "aws_kms_alias" "state" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.state.key_id
}

resource "aws_iam_instance_profile" "iac" {
  count = var.create_iam_instance_profile ? 1 : 0
  name  = var.role_name
  role  = aws_iam_role.iac.name
  tags  = var.tags
}


