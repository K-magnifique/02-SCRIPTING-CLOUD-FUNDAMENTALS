#!/usr/bin/env bash
set -euo pipefail
trap 'echo "[FATAL] ${BASH_SOURCE[0]}:${LINENO}: command failed: ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

remediate_tags() {
  local kind="$1" resource_id="$2"
  case "$kind" in
    "EC2 instance"|"Security group")
      aws_cli ec2 create-tags --resources "$resource_id" --tags \
        "Key=cost-center,Value=${COST_CENTER}" \
        "Key=environment,Value=${ENVIRONMENT_TAG}" \
        "Key=owner,Value=${OWNER_TAG}"
      ;;
    "S3 bucket")
      aws_cli s3api put-bucket-tagging --bucket "$resource_id" --tagging \
        "TagSet=[{Key=Name,Value=${resource_id}},{Key=cost-center,Value=${COST_CENTER}},{Key=environment,Value=${ENVIRONMENT_TAG}},{Key=owner,Value=${OWNER_TAG}}]"
      ;;
  esac
}


check_tags() {
  local kind="$1" name="$2" resource_id="$3" tags_json="$4"
  local drift=0 pair key expected actual
  for pair in "cost-center=${COST_CENTER}" "environment=${ENVIRONMENT_TAG}" "owner=${OWNER_TAG}"; do
    key="${pair%%=*}"
    expected="${pair#*=}"
    actual="$(printf '%s' "$tags_json" | jq -r --arg k "$key" '.[] | select(.Key == $k) | .Value')"
    if [ "$actual" != "$expected" ]; then
      log "${kind} ${name}: tag '${key}' = '${actual:-<missing>}' (expected '${expected}')"
      drift=1
    fi
  done

  if [ "$drift" -eq 1 ]; then
    if remediate_tags "$kind" "$resource_id"; then
      log "${kind} ${name}: REMEDIATED"
    else
      log "${kind} ${name}: REMEDIATION FAILED -- manual attention needed"
      REPORT_HAD_FAILURE=1
    fi
  else
    log "${kind} ${name}: tags compliant"
  fi
}


check_instance() {
  local name="$1" info state instance_id tags_json
  info="$(aws_cli ec2 describe-instances \
    --filters "Name=tag:Name,Values=${name}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0]' --output json)"

  if [ "$info" = "null" ]; then
    log "EC2 instance ${name}: NOT FOUND"
    return
  fi

  state="$(printf '%s' "$info" | jq -r '.State.Name')"
  instance_id="$(printf '%s' "$info" | jq -r '.InstanceId')"
  tags_json="$(printf '%s' "$info" | jq -c '.Tags')"
  log "EC2 instance ${name}: state=${state}"
  check_tags "EC2 instance" "$name" "$instance_id" "$tags_json"
}


check_security_group() {
  local name="$1" info sg_id tags_json
  info="$(aws_cli ec2 describe-security-groups \
    --filters "Name=group-name,Values=${name}" \
    --query 'SecurityGroups[0]' --output json)"

  if [ "$info" = "null" ]; then
    log "Security group ${name}: NOT FOUND"
    return
  fi

  sg_id="$(printf '%s' "$info" | jq -r '.GroupId')"
  tags_json="$(printf '%s' "$info" | jq -c '.Tags')"
  log "Security group ${name}: present"
  check_tags "Security group" "$name" "$sg_id" "$tags_json"
}

check_bucket() {
  local name="$1" tags_json
  if ! aws_cli s3api head-bucket --bucket "$name" 2>/dev/null; then
    log "S3 bucket ${name}: NOT FOUND"
    return
  fi

  tags_json="$(aws_cli s3api get-bucket-tagging --bucket "$name" --query 'TagSet' --output json)"
  log "S3 bucket ${name}: present"
  check_tags "S3 bucket" "$name" "$name" "$tags_json"
}

main() {
  require_cmd aws
  require_cmd jq
  load_env "${SCRIPT_DIR}/../.env"
  validate_config
  require_env PERSONA_AWS_PROFILE

  AWS_PROFILE="$PERSONA_AWS_PROFILE"
  REPORT_HAD_FAILURE=0

  log "Status report for ${STUDENT_ID} (using ${AWS_PROFILE})"
  check_instance "$(resource_name app-server)"
  check_security_group "$(resource_name sg)"
  check_bucket "$(resource_name app-config)"
  log "Status report complete."
  [ "$REPORT_HAD_FAILURE" -eq 0 ] || exit 1
}

main "$@"

