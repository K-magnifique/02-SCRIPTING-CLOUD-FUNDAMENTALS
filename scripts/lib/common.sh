#!/usr/bin/env bash
# Shared helpers for the Kente Retail lab scripts (provision / cleanup / status-report).

log()  { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }
die()  { log "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found on PATH"
}

load_env() {
  local env_file="$1"
  [ -f "$env_file" ] || die "${env_file} not found — copy .env.example to .env and fill in your assigned values"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

require_env() {
  local name="$1"
  local value="${!name:-}"
  [ -n "$value" ] || die "required variable ${name} is not set in .env"
}

validate_student_id() {
  [[ "$STUDENT_ID" =~ ^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$ ]] \
    || die "STUDENT_ID '${STUDENT_ID}' must be lowercase alphanumeric/hyphen (your assigned sandbox prefix)"
}

validate_region() {
  [[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]] \
    || die "AWS_REGION '${AWS_REGION}' doesn't look like a real AWS region code"
}

validate_instance_type() {
  case "$INSTANCE_TYPE" in
    t2.micro|t2.small|t3.micro|t3.small) ;;
    *) die "INSTANCE_TYPE '${INSTANCE_TYPE}' is outside the allowed list (t2/t3 micro|small) — kept small to protect the \$20 budget" ;;
  esac
}

validate_config() {
  for var in STUDENT_ID AWS_REGION AWS_PROFILE INSTANCE_TYPE COST_CENTER ENVIRONMENT_TAG OWNER_TAG; do
    require_env "$var"
  done
  validate_student_id
  validate_region
  validate_instance_type
}

aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" "$@"
}

resource_name() {
  # $1: suffix, e.g. "sg" / "app-server" / "app-config"
  printf '%s-kente-%s' "$STUDENT_ID" "$1"
}

tag_spec() {
  # $1: ResourceType (instance|volume|security-group), $2: Name tag value
  printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=cost-center,Value=%s},{Key=environment,Value=%s},{Key=owner,Value=%s}]' \
    "$1" "$2" "$COST_CENTER" "$ENVIRONMENT_TAG" "$OWNER_TAG"
}
