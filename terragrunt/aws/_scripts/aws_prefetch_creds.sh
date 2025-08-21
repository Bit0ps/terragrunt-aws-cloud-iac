#!/usr/bin/env bash
set -euo pipefail

# A helper to pre-fetch short-lived AWS credentials for Terragrunt bootstrap runs.
#
# Requires: aws, jq
#
# Modes:
#   - session-token: Obtain STS session tokens for an IAM user (typically requires MFA)
#   - assume-role:   Assume a role and emit temporary creds (optionally using MFA)
#
# Outputs shell export lines to stdout. You can source them into your shell:
#   eval "$(./aws_prefetch_creds.sh session-token --mfa-serial arn:aws:iam::123456789012:mfa/me --mfa-code 123456)"
#   eval "$(./aws_prefetch_creds.sh assume-role --role-arn arn:aws:iam::123456789012:role/Admin --session-name iac-bootstrap)"

command -v aws >/dev/null 2>&1 || { echo "aws CLI is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }

die() { echo "$*" >&2; exit 1; }

# Call aws with optional profile (Bash 3 compatible)
run_aws() {
  if [[ -n "${PROFILE_NAME:-}" ]]; then
    aws --profile "$PROFILE_NAME" "$@"
  else
    aws "$@"
  fi
}

# Return current ARN for the configured profile (if any)
current_arn() {
  run_aws sts get-caller-identity --query Arn --output text 2>/dev/null || true
}

# Read a value from ~/.aws/config for a profile
profile_get() {
  local key=$1 profile_name=$2
  aws configure get "profile.${profile_name}.${key}" 2>/dev/null || true
}

# Try to infer MFA serial for IAM user attached to given profile
infer_mfa_serial_from_user() {
  local user
  user=$(run_aws iam get-user --query 'User.UserName' --output text 2>/dev/null || true)
  if [[ -n "$user" && "$user" != "None" && "$user" != "null" ]]; then
    run_aws iam list-mfa-devices --user-name "$user" --query 'MFADevices[0].SerialNumber' --output text 2>/dev/null || true
  fi
}

# Resolve MFA serial from explicit arg, profile, IAM user, or device name + account id
resolve_mfa_serial() {
  local explicit_serial=$1 profile_name=$2 mfa_device_name=$3 account_id=$4
  local serial="$explicit_serial"
  if [[ -z "$serial" && -n "$profile_name" ]]; then
    serial=$(profile_get mfa_serial "$profile_name")
  fi
  if [[ -z "$serial" && -n "$profile_name" ]]; then
    # temporarily set PROFILE_NAME for run_aws
    local old_profile=${PROFILE_NAME:-}
    PROFILE_NAME="$profile_name"
    serial=$(infer_mfa_serial_from_user)
    PROFILE_NAME="$old_profile"
  fi
  if [[ -z "$serial" && -n "$mfa_device_name" ]]; then
    [[ -z "$account_id" ]] && die "--account-id (or AWS_ACCOUNT_ID env) is required when using --mfa-device-name"
    serial="arn:aws:iam::${account_id}:mfa/${mfa_device_name}"
  fi
  echo -n "$serial"
}

usage() {
  cat <<'USAGE'
Usage:
  aws_prefetch_creds.sh profile \
    --profile <source_profile>

  aws_prefetch_creds.sh session-token \
    [--profile <source_profile>] \
    [--mfa-serial <MFA_DEVICE_ARN> | --mfa-device-name <MFA_DEVICE_NAME> [--account-id <ACCOUNT_ID>]] \
    [--mfa-code <MFA_TOTP_CODE>] \
    [--no-mfa] \
    [--duration-seconds 3600]

  aws_prefetch_creds.sh assume-role \
    [--profile <source_profile>] \
    [--role-arn <ROLE_ARN>] \
    --session-name <SESSION_NAME> \
    [--external-id <EXTERNAL_ID>] \
    [--mfa-serial <MFA_DEVICE_ARN> | --mfa-device-name <MFA_DEVICE_NAME> [--account-id <ACCOUNT_ID>]] \
    [--mfa-code <MFA_TOTP_CODE>] \
    [--no-mfa] \
    [--duration-seconds 3600]

Notes:
  - This script prints export statements. To load them into your shell, wrap with: eval "$(...)"
  - When using --profile, the configured profile must already be authenticated (SSO, aws-vault, etc.).
USAGE
}

emit_exports() {
  local json_file="$1"
  local prefix=${2:-}
  local ak sk st
  ak=$(jq -r .Credentials.AccessKeyId "$json_file")
  sk=$(jq -r .Credentials.SecretAccessKey "$json_file")
  st=$(jq -r .Credentials.SessionToken "$json_file")
  if [[ -z "$ak" || -z "$sk" || -z "$st" || "$ak" == "null" || "$sk" == "null" || "$st" == "null" ]]; then
    echo "Failed to parse credentials from STS response" >&2
    exit 1
  fi
  echo "export ${prefix}AWS_ACCESS_KEY_ID=$ak"
  echo "export ${prefix}AWS_SECRET_ACCESS_KEY=$sk"
  echo "export ${prefix}AWS_SESSION_TOKEN=$st"
}

mode=${1:-}
shift || true

case "$mode" in
  profile)
    PROFILE_ARGS=(); PROFILE_NAME=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --profile) PROFILE_NAME="$2"; PROFILE_ARGS=(--profile "$2"); shift 2;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown arg: $1" >&2; usage; exit 1;;
      esac
    done
    if [[ -z "$PROFILE_NAME" ]]; then
      echo "--profile is required for profile mode" >&2; usage; exit 1
    fi
    # Let AWS CLI handle any role chaining/SSO and just export the effective creds
    PROFILE_NAME="$PROFILE_NAME" run_aws configure export-credentials --format env
    exit 0
    ;;

  session-token)
    MFA_SERIAL=""; MFA_DEVICE_NAME=""; ACCOUNT_ID_INPUT=""; MFA_CODE=""; DURATION=3600; PROFILE_ARGS=(); PROFILE_NAME=""; NO_MFA=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --mfa-serial) MFA_SERIAL="$2"; shift 2;;
        --mfa-device-name) MFA_DEVICE_NAME="$2"; shift 2;;
        --account-id) ACCOUNT_ID_INPUT="$2"; shift 2;;
        --mfa-code) MFA_CODE="$2"; shift 2;;
        --duration-seconds) DURATION="$2"; shift 2;;
        --profile) PROFILE_NAME="$2"; PROFILE_ARGS=(--profile "$2"); shift 2;;
        --no-mfa) NO_MFA=true; shift 1;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown arg: $1" >&2; usage; exit 1;;
      esac
    done
    # If NO_MFA is set, do not require serial/code and call get-session-token without MFA params
    if [[ "$NO_MFA" == true ]]; then
      tmp=$(mktemp)
      PROFILE_NAME="$PROFILE_NAME" run_aws sts get-session-token \
        --duration-seconds "$DURATION" > "$tmp"
      emit_exports "$tmp"; rm -f "$tmp"; exit 0
    fi
    # Otherwise, require a valid code and resolve MFA serial if needed
    if [[ -z "$MFA_CODE" ]]; then
      echo "--mfa-code is required for session-token mode (omit or use --no-mfa only if your IAM policy allows token without MFA)" >&2
      usage; exit 1
    fi
    if [[ -n "$PROFILE_NAME" ]]; then
      # Refuse to call get-session-token with assumed-role/SSO creds
      PROFILE_NAME="$PROFILE_NAME"; CURRENT_ARN=$(current_arn)
      if [[ "$CURRENT_ARN" == *":assumed-role/"* || "$CURRENT_ARN" == *":AWSReservedSSO_"* ]]; then
        die "Profile '$PROFILE_NAME' appears to use assumed-role/SSO credentials; use 'assume-role' mode instead of 'session-token'."
      fi
    fi
    MFA_SERIAL=$(resolve_mfa_serial "$MFA_SERIAL" "$PROFILE_NAME" "$MFA_DEVICE_NAME" "${ACCOUNT_ID_INPUT:-${AWS_ACCOUNT_ID:-}}")
    [[ -z "$MFA_SERIAL" ]] && die "Unable to resolve MFA serial. Provide --mfa-serial, or configure mfa_serial in profile, or pass --mfa-device-name [--account-id]."
    tmp=$(mktemp)
    PROFILE_NAME="$PROFILE_NAME" run_aws sts get-session-token \
      --serial-number "$MFA_SERIAL" \
      --token-code "$MFA_CODE" \
      --duration-seconds "$DURATION" > "$tmp"
    emit_exports "$tmp"
    rm -f "$tmp"
    ;;

  assume-role)
    ROLE_ARN=""; SESSION_NAME=""; EXTERNAL_ID_ARGS=(); DURATION=3600; PROFILE_ARGS=(); PROFILE_NAME=""; MFA_SERIAL=""; MFA_DEVICE_NAME=""; ACCOUNT_ID_INPUT=""; MFA_CODE=""; mfa_args=(); NO_MFA=false
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --role-arn) ROLE_ARN="$2"; shift 2;;
        --session-name) SESSION_NAME="$2"; shift 2;;
        --external-id) EXTERNAL_ID_ARGS=(--external-id "$2"); shift 2;;
        --duration-seconds) DURATION="$2"; shift 2;;
        --profile) PROFILE_NAME="$2"; PROFILE_ARGS=(--profile "$2"); shift 2;;
        --mfa-serial) MFA_SERIAL="$2"; shift 2;;
        --mfa-device-name) MFA_DEVICE_NAME="$2"; shift 2;;
        --account-id) ACCOUNT_ID_INPUT="$2"; shift 2;;
        --mfa-code) MFA_CODE="$2"; shift 2;;
        --no-mfa) NO_MFA=true; shift 1;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown arg: $1" >&2; usage; exit 1;;
      esac
    done
    if [[ -z "$ROLE_ARN" && -n "$PROFILE_NAME" ]]; then
      ROLE_ARN=$(profile_get role_arn "$PROFILE_NAME")
    fi
    if [[ -z "$ROLE_ARN" || -z "$SESSION_NAME" ]]; then
      echo "--role-arn and --session-name are required for assume-role mode" >&2
      usage; exit 1
    fi
    # Only build MFA args if NO_MFA is false
    mfa_args=()
    if [[ "$NO_MFA" == false ]]; then
      MFA_SERIAL=$(resolve_mfa_serial "$MFA_SERIAL" "$PROFILE_NAME" "$MFA_DEVICE_NAME" "${ACCOUNT_ID_INPUT:-${AWS_ACCOUNT_ID:-}}")
      if [[ -n "$MFA_SERIAL" ]]; then
        [[ -z "$MFA_CODE" ]] && die "--mfa-code is required when MFA serial is specified (via flag or profile)"
        mfa_args=(--serial-number "$MFA_SERIAL" --token-code "$MFA_CODE")
      fi
    fi
    tmp=$(mktemp)
    PROFILE_NAME="$PROFILE_NAME" run_aws sts assume-role \
      --role-arn "$ROLE_ARN" \
      --role-session-name "$SESSION_NAME" \
      "${EXTERNAL_ID_ARGS[@]}" \
      "${mfa_args[@]}" \
      --duration-seconds "$DURATION" > "$tmp"
    emit_exports "$tmp"
    rm -f "$tmp"
    ;;

  -h|--help|*)
    usage; exit 1;;
esac


