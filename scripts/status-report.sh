#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[FATAL] ${BASH_SOURCE[0]}:${LINENO}: command failed: ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

check_tags() {
  local kind="$1" name="$2" tags_json="$3"
  local ok=1 pair key expected actual
  for pair in "cost-center=${COST_CENTER}" "environment=${ENVIRONMENT_TAG}" "owner=${OWNER_TAG}"; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(printf '%s' "$tags_json" | jq -r --arg k "$key" '.[] | select(.Key == $k) | .Value')"
    if [ "$actual" != "$expected" ]; then
      log "${kind} ${name}: tag '${key}' = '${actual:-<missing>}' (expected '${expected}')"
      ok=0
    fi
  done
  [ "$ok" -eq 1 ] && log "${kind} ${name}: tags compliant"
}

check_instance() {
  local name="$1" info state tags_json
  info="$(aws_cli ec2 describe-instances \
    --filters "Name=tag:Name,Values=${name}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0]' --output json)"

  if [ "$info" = "null" ]; then
    log "EC2 instance ${name}: NOT FOUND"
    return
  fi

  state="$(printf '%s' "$info" | jq -r '.State.Name')"
  tags_json="$(printf '%s' "$info" | jq -c '.Tags')"
  log "EC2 instance ${name}: state=${state}"
  check_tags "EC2 instance" "$name" "$tags_json"
}

check_security_group() {
  local name="$1" info tags_json
  info="$(aws_cli ec2 describe-security-groups \
    --filters "Name=group-name,Values=${name}" \
    --query 'SecurityGroups[0]' --output json)"

  if [ "$info" = "null" ]; then
    log "Security group ${name}: NOT FOUND"
    return
  fi

  tags_json="$(printf '%s' "$info" | jq -c '.Tags')"
  log "Security group ${name}: present"
  check_tags "Security group" "$name" "$tags_json"
}

check_bucket() {
  local name="$1" tags_json
  if ! aws_cli s3api head-bucket --bucket "$name" 2>/dev/null; then
    log "S3 bucket ${name}: NOT FOUND"
    return
  fi

  tags_json="$(aws_cli s3api get-bucket-tagging --bucket "$name" --query 'TagSet' --output json)"
  log "S3 bucket ${name}: present"
  check_tags "S3 bucket" "$name" "$tags_json"
}

main() {
  require_cmd aws
  require_cmd jq
  load_env "${SCRIPT_DIR}/../.env"
  validate_config
  require_env PERSONA_AWS_PROFILE

  AWS_PROFILE="$PERSONA_AWS_PROFILE"

  log "Status report for ${STUDENT_ID} (using ${AWS_PROFILE})"
  check_instance "$(resource_name app-server)"
  check_security_group "$(resource_name sg)"
  check_bucket "$(resource_name app-config)"
  log "Status report complete."
}

main "$@"

