output "iac_user_name" {
  value       = aws_iam_user.bootstrap.name
  description = "Name of the created bootstrap IAM user"
}

output "iac_user_access_key_id" {
  value       = try(aws_iam_access_key.bootstrap[0].id, null)
  description = "Access key ID for the bootstrap IAM user (if created)"
  sensitive   = true
}

output "iac_user_secret_access_key" {
  value       = try(aws_iam_access_key.bootstrap[0].secret, null)
  description = "Secret access key for the bootstrap IAM user (if created)"
  sensitive   = true
}

output "iac_role_arn" {
  value       = aws_iam_role.iac.arn
  description = "ARN of the created IaC role"
}

output "iac_instance_profile_name" {
  value       = try(aws_iam_instance_profile.iac[0].name, null)
  description = "Name of the IAM instance profile created for the IaC role (if enabled)"
}

output "iac_instance_profile_arn" {
  value       = try(aws_iam_instance_profile.iac[0].arn, null)
  description = "ARN of the IAM instance profile created for the IaC role (if enabled)"
}

output "iac_state_encryption_kms_key_arn" {
  value       = aws_kms_key.state.arn
  description = "ARN of the created KMS key used for state encryption"
}


