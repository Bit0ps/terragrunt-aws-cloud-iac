variable "user_name" {
  type        = string
  description = "Name of the IAM user to create for bootstrapping"
}

variable "role_name" {
  type        = string
  description = "Name of the IAM role to create and assume for IaC operations"
}

variable "iam_role_policy_json" {
  type        = string
  description = "IAM policy JSON to attach to the created role"
}

variable "kms_key_alias" {
  type        = string
  description = "Alias for the KMS key used to encrypt OpenTofu/Terragrunt state"
  default     = "alias/terraform-state"
}

variable "kms_key_policy_json" {
  type        = string
  description = "KMS key policy JSON for the state encryption key. If null, a sensible default allowing the created role and user to use the key will be applied."
  default     = null
}

variable "create_access_key" {
  type        = bool
  description = "Whether to create an access key for the bootstrap IAM user"
  default     = true
}

variable "attach_user_assume_role_policy" {
  type        = bool
  description = "Attach an inline policy to the bootstrap IAM user allowing sts:AssumeRole into the created role"
  default     = true
}

variable "role_max_session_duration" {
  type        = number
  description = "Maximum session duration, in seconds, for the created IAM role (900-43200)."
  default     = 3600
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Optional IAM permissions boundary ARN to attach to both the role and the bootstrap user."
  default     = null
}

variable "create_iam_instance_profile" {
  type        = bool
  description = "Whether to create an IAM instance profile for the created role"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to created resources"
  default     = {}
}


