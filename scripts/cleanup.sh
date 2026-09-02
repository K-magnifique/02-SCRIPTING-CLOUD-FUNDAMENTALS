#!/usr/bin/env bash
# Tears down everything provision.sh creates. Safe to re-run against an
# already-empty state — every step checks existence before acting.
set -euo pipefail
trap 'echo "[FATAL] ${BASH_SOURCE[0]}:${LINENO}: command failed: ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Terminate first — teardown order is the reverse of creation order, since
# the security group can't be deleted while the instance still uses it.
# "Already gone" here is the expected steady state on a re-run, not an error.
terminate_instance() {
  local name="$1" instance_id
  instance_id="$(aws_cli ec2 describe-instances \
    --filters "Name=tag:Name,Values=${name}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[0].InstanceId' --output text)"

  if [ -z "$instance_id" ] || [ "$instance_id" = "None" ]; then
    log "EC2 instance ${name} already gone"
    return
  fi

  log "Terminating EC2 instance ${name} (${instance_id})"
  aws_cli ec2 terminate-instances --instance-ids "$instance_id" >/dev/null \
    || die "failed to terminate instance ${instance_id}"
  log "Waiting for ${instance_id} to terminate..."
  aws_cli ec2 wait instance-terminated --instance-ids "$instance_id" \
    || die "instance ${instance_id} did not reach terminated state"
}

# Only safe to call after the instance has actually finished terminating.
delete_security_group() {
  local name="$1" vpc_id="$2" sg_id
  sg_id="$(aws_cli ec2 describe-security-groups \
    --filters "Name=group-name,Values=${name}" "Name=vpc-id,Values=${vpc_id}" \
    --query 'SecurityGroups[0].GroupId' --output text)"

  if [ -z "$sg_id" ] || [ "$sg_id" = "None" ]; then
    log "Security group ${name} already gone"
    return
  fi

  log "Deleting security group ${name} (${sg_id})"
  aws_cli ec2 delete-security-group --group-id "$sg_id" \
    || die "failed to delete security group ${name}"
}

# S3 won't delete a non-empty bucket, so objects have to go first. `aws s3 rm
# --recursive` (the high-level command) handles bulk deletion in one call —
# s3api has no equivalent single "delete everything under this prefix" call.
empty_and_delete_bucket() {
  local name="$1"
  if ! aws_cli s3api head-bucket --bucket "$name" 2>/dev/null; then
    log "S3 bucket ${name} already gone"
    return
  fi

  log "Emptying and deleting S3 bucket ${name}"
  aws_cli s3 rm "s3://${name}" --recursive >/dev/null \
    || die "failed to empty S3 bucket ${name}"

  aws_cli s3api delete-bucket --bucket "$name" \
    || die "failed to delete S3 bucket ${name}"
}

# Proves the "zero resources remain" acceptance criterion by independently
# re-checking all three resources, rather than just trusting the delete calls
# above didn't error. Reports every leftover resource found, not just the first.
verify_clean() {
  local sg_name="$1" instance_name="$2" bucket_name="$3"
  local remaining=0

  if aws_cli ec2 describe-instances \
      --filters "Name=tag:Name,Values=${instance_name}" \
        "Name=instance-state-name,Values=pending,running,stopping,stopped" \
      --query 'Reservations[].Instances[0].InstanceId' --output text \
      | grep -qv '^None$\|^$'; then
    log "REMAINING: EC2 instance ${instance_name} still present"
    remaining=1
  fi

  local vpc_id
  vpc_id="$(aws_cli ec2 describe-vpcs --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' --output text)"
  if aws_cli ec2 describe-security-groups \
      --filters "Name=group-name,Values=${sg_name}" "Name=vpc-id,Values=${vpc_id}" \
      --query 'SecurityGroups[0].GroupId' --output text \
      | grep -qv '^None$\|^$'; then
    log "REMAINING: security group ${sg_name} still present"
    remaining=1
  fi

  if aws_cli s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
    log "REMAINING: S3 bucket ${bucket_name} still present"
    remaining=1
  fi

  if [ "$remaining" -eq 0 ]; then
    log "Verified: zero resources remain for ${STUDENT_ID}."
  else
    die "cleanup incomplete — see REMAINING lines above"
  fi
}

main() {
  require_cmd aws
  load_env "${SCRIPT_DIR}/../.env"
  validate_config

  local sg_name instance_name bucket_name
  sg_name="$(resource_name sg)"
  instance_name="$(resource_name app-server)"
  bucket_name="$(resource_name app-config)"

  local vpc_id
  vpc_id="$(aws_cli ec2 describe-vpcs --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' --output text)"

  # Order matters: instance, then its security group, then the independent
  # bucket, then verify everything is actually gone.
  terminate_instance "$instance_name"
  delete_security_group "$sg_name" "$vpc_id"
  empty_and_delete_bucket "$bucket_name"
  verify_clean "$sg_name" "$instance_name" "$bucket_name"
}

main "$@"
