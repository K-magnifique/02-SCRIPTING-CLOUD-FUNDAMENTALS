#!/usr/bin/env bash
# Creates the least-privilege IAM group/policy/user for the persona in
# ../PERSONA_BRIEF.md. Simpler idempotency than provision.sh: create-if-
# missing only — doesn't handle updating an existing policy's *content*,
# since this policy is meant to be finalized, not iterated on repeatedly.
set -euo pipefail
trap 'echo "[FATAL] ${BASH_SOURCE[0]}:${LINENO}: command failed: ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# get-group either succeeds (exists) or fails (doesn't) — no text output to
# parse, unlike the EC2/S3 checks in provision.sh.
ensure_iam_group() {
  local name="$1"
  if aws_cli iam get-group --group-name "$name" >/dev/null 2>&1; then
    log "IAM group ${name} already exists"
  else
    log "Creating IAM group ${name}"
    aws_cli iam create-group --group-name "$name" >/dev/null
  fi
}

# IAM has no "get policy by name" API — get-policy needs the full ARN. But a
# policy ARN is fully predictable (account id + fixed pattern), so it's built
# here rather than needing to create the policy first just to learn its ARN.
ensure_iam_policy() {
  local name="$1" policy_file="$2" account_id policy_arn
  [ -f "$policy_file" ] || die "policy file not found: ${policy_file}"
  account_id="$(aws_cli sts get-caller-identity --query Account --output text)"
  policy_arn="arn:aws:iam::${account_id}:policy/${name}"

  if aws_cli iam get-policy --policy-arn "$policy_arn" >/dev/null 2>&1; then
    log "IAM policy ${name} already exists"
  else
    log "Creating IAM policy ${name} from ${policy_file}"
    # Read the file ourselves and pass the JSON text directly, rather than
    # --policy-document file://... — on Windows/Git Bash, aws.exe (a native
    # Windows binary) can't resolve the POSIX-style /c/... path bash builds,
    # so a file:// reference fails even though the file genuinely exists.
    aws_cli iam create-policy --policy-name "$name" \
      --policy-document "$(cat "$policy_file")" >/dev/null
  fi

  printf '%s' "$policy_arn"
}

ensure_iam_user() {
  local name="$1"
  if aws_cli iam get-user --user-name "$name" >/dev/null 2>&1; then
    log "IAM user ${name} already exists"
  else
    log "Creating IAM user ${name}"
    aws_cli iam create-user --user-name "$name" >/dev/null
  fi
}

# No existence check here, deliberately: unlike create-group/create-user/
# create-policy (which error on a duplicate name), attach-group-policy is
# itself idempotent — calling it again when already attached just succeeds.
attach_policy_to_group() {
  local group="$1" policy_arn="$2"
  log "Ensuring ${policy_arn} is attached to ${group}"
  aws_cli iam attach-group-policy --group-name "$group" --policy-arn "$policy_arn"
}

# Same reasoning as attach_policy_to_group — add-user-to-group is idempotent
# at the AWS API level, so no manual describe-before-act check is needed.
add_user_to_group() {
  local user="$1" group="$2"
  log "Ensuring ${user} is in ${group}"
  aws_cli iam add-user-to-group --user-name "$user" --group-name "$group"
}

main() {
  require_cmd aws
  load_env "${SCRIPT_DIR}/../.env"
  validate_config

  local group_name policy_name user_name policy_file policy_arn
  # Reuses the same ${STUDENT_ID}-kente-<suffix> convention as the EC2/SG/S3
  # names, so it's obvious at a glance which IAM objects belong to this lab.
  group_name="$(resource_name group)"
  policy_name="$(resource_name policy)"
  user_name="$(resource_name user)"
  policy_file="${SCRIPT_DIR}/../iam/policy.json"

  ensure_iam_group "$group_name"
  policy_arn="$(ensure_iam_policy "$policy_name" "$policy_file")"
  ensure_iam_user "$user_name"
  attach_policy_to_group "$group_name" "$policy_arn"
  add_user_to_group "$user_name" "$group_name"

  log "IAM setup complete."
  log "  group:  ${group_name}"
  log "  policy: ${policy_name} (${policy_arn})"
  log "  user:   ${user_name}"
}

main "$@"
