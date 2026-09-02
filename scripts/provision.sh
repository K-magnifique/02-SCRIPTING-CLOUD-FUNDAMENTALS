#!/usr/bin/env bash
# Idempotent provisioning: security group, EC2 instance, S3 bucket — tagged,
# re-runnable without creating duplicates. See ../.env.example for required config.
set -euo pipefail
trap 'echo "[FATAL] ${BASH_SOURCE[0]}:${LINENO}: command failed: ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Returns the AMI to launch: an explicit AMI_ID override if set, otherwise the
# latest Amazon Linux 2023 AMI resolved dynamically via SSM's public parameter
# store — avoids hardcoding a region-specific ID that would go stale.
resolve_ami() {
  if [ -n "${AMI_ID:-}" ]; then
    printf '%s' "$AMI_ID"
    return
  fi
  aws_cli ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query 'Parameters[0].Value' --output text
}

# Every new AWS account gets one default VPC per region; this script assumes
# it still exists rather than creating a VPC of its own.
ensure_default_vpc() {
  local vpc_id
  vpc_id="$(aws_cli ec2 describe-vpcs --filters Name=isDefault,Values=true \
    --query 'Vpcs[0].VpcId' --output text)"
  [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ] \
    || die "no default VPC found in ${AWS_REGION} — this script assumes one exists"
  printf '%s' "$vpc_id"
}

# Idempotency pattern used throughout: describe first, only create if not found.
# Security group names are unique per-VPC, so the existence check filters on
# both name and vpc-id.
ensure_security_group() {
  local name="$1" vpc_id="$2" sg_id
  sg_id="$(aws_cli ec2 describe-security-groups \
    --filters "Name=group-name,Values=${name}" "Name=vpc-id,Values=${vpc_id}" \
    --query 'SecurityGroups[0].GroupId' --output text)"

  if [ -z "$sg_id" ] || [ "$sg_id" = "None" ]; then
    log "Creating security group ${name}"
    sg_id="$(aws_cli ec2 create-security-group \
      --group-name "$name" \
      --description "Kente Retail lab - ${STUDENT_ID}" \
      --vpc-id "$vpc_id" \
      --tag-specifications "$(tag_spec security-group "$name")" \
      --query 'GroupId' --output text)"
    [ -n "$sg_id" ] && [ "$sg_id" != "None" ] || die "failed to create security group ${name}"
  else
    log "Security group ${name} already exists (${sg_id})"
  fi

  if [ -n "${ALLOWED_SSH_CIDR:-}" ]; then
    local existing
    existing="$(aws_cli ec2 describe-security-groups --group-ids "$sg_id" \
      --query "SecurityGroups[0].IpPermissions[?ToPort==\`22\`].IpRanges[?CidrIp=='${ALLOWED_SSH_CIDR}'].CidrIp" \
      --output text)"
    if [ -z "$existing" ]; then
      log "Authorizing SSH from ${ALLOWED_SSH_CIDR} on ${name}"
      aws_cli ec2 authorize-security-group-ingress \
        --group-id "$sg_id" --protocol tcp --port 22 --cidr "$ALLOWED_SSH_CIDR" >/dev/null \
        || die "failed to authorize SSH ingress on ${name}"
    else
      log "SSH ingress from ${ALLOWED_SSH_CIDR} already present on ${name}"
    fi
  else
    log "ALLOWED_SSH_CIDR not set — leaving ${name} closed to inbound traffic"
  fi

  printf '%s' "$sg_id"
}

# Same describe-then-create idempotency pattern, keyed on the instance's
# Name tag. --client-token adds a second, API-level layer of idempotency in
# case this exact call is ever retried (e.g. a network blip).
ensure_ec2_instance() {
  local name="$1" sg_id="$2" instance_id ami_id
  instance_id="$(aws_cli ec2 describe-instances \
    --filters "Name=tag:Name,Values=${name}" \
      "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[0].InstanceId' --output text)"

  if [ -n "$instance_id" ] && [ "$instance_id" != "None" ]; then
    log "EC2 instance ${name} already exists (${instance_id})"
    printf '%s' "$instance_id"
    return
  fi

  ami_id="$(resolve_ami)"
  [ -n "$ami_id" ] && [ "$ami_id" != "None" ] || die "could not resolve an AMI ID"

  log "Launching EC2 instance ${name} (${INSTANCE_TYPE}, ${ami_id})"
  # Two tag-specifications: the instance and its EBS volume are separate
  # taggable resources in AWS, so both need tagging explicitly.
  instance_id="$(aws_cli ec2 run-instances \
    --image-id "$ami_id" \
    --instance-type "$INSTANCE_TYPE" \
    --security-group-ids "$sg_id" \
    --count 1 \
    --client-token "${name}-run" \
    --tag-specifications "$(tag_spec instance "$name")" "$(tag_spec volume "$name")" \
    --query 'Instances[0].InstanceId' --output text)"
  [ -n "$instance_id" ] && [ "$instance_id" != "None" ] || die "failed to launch EC2 instance ${name}"

  printf '%s' "$instance_id"
}

# S3 idempotency check uses head-bucket's exit code rather than parsing text
# output, since head-bucket returns no data — just success/failure.
ensure_s3_bucket() {
  local name="$1"
  if aws_cli s3api head-bucket --bucket "$name" 2>/dev/null; then
    log "S3 bucket ${name} already exists"
  else
    log "Creating S3 bucket ${name}"
    # us-east-1 is the one region where create-bucket rejects a
    # LocationConstraint; every other region requires one.
    if [ "$AWS_REGION" = "us-east-1" ]; then
      aws_cli s3api create-bucket --bucket "$name" >/dev/null \
        || die "failed to create S3 bucket ${name}"
    else
      aws_cli s3api create-bucket --bucket "$name" \
        --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null \
        || die "failed to create S3 bucket ${name}"
    fi
  fi

  # Runs unconditionally (new or pre-existing) since create-bucket has no
  # --tag-specifications option — bucket tagging is always a separate call.
  aws_cli s3api put-bucket-tagging --bucket "$name" --tagging \
    "TagSet=[{Key=Name,Value=${name}},{Key=cost-center,Value=${COST_CENTER}},{Key=environment,Value=${ENVIRONMENT_TAG}},{Key=owner,Value=${OWNER_TAG}}]" \
    || die "failed to tag S3 bucket ${name}"
}

main() {
  require_cmd aws
  load_env "${SCRIPT_DIR}/../.env"
  validate_config

  local sg_name instance_name bucket_name vpc_id sg_id instance_id
  sg_name="$(resource_name sg)"
  instance_name="$(resource_name app-server)"
  bucket_name="$(resource_name app-config)"

  # Dependency order: VPC before security group, security group before the
  # instance that references it. The bucket has no dependency on the others.
  vpc_id="$(ensure_default_vpc)"
  sg_id="$(ensure_security_group "$sg_name" "$vpc_id")"
  instance_id="$(ensure_ec2_instance "$instance_name" "$sg_id")"
  ensure_s3_bucket "$bucket_name"

  log "Provisioning complete."
  log "  security group: ${sg_name} (${sg_id})"
  log "  ec2 instance:   ${instance_name} (${instance_id})"
  log "  s3 bucket:      ${bucket_name}"
}

main "$@"
