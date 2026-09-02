#!/usr/bin/env bash
# Shared helpers for the Kente Retail lab scripts (provision / cleanup / iam-setup).

# On Git Bash/MSYS, any argument starting with "/" (e.g. an SSM parameter name
# like /aws/service/...) gets auto-converted into a Windows path before aws.exe
# ever sees it. No-op on Linux/macOS.
export MSYS_NO_PATHCONV=1

# Timestamped log line — deliberately to stderr, not stdout. Several functions
# in these scripts (ensure_security_group, ensure_ec2_instance, ensure_iam_policy)
# call log() for progress messages AND return a value via a final `printf` to
# stdout, then get invoked as `x="$(that_function ...)"`. Command substitution
# captures everything a function writes to stdout — if log() also wrote to
# stdout, its messages would get prepended into the captured "return value",
# silently corrupting it (this actually happened: a log line ended up glued to
# an IAM policy ARN, which AWS then rejected as invalid). Writing to stderr
# keeps progress output visible on the terminal without polluting anything
# a caller captures via $(...).
log()  { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*" >&2; }
# Log an error and exit non-zero. Used for anything that should stop the script
# with a clear message instead of failing later on a confusing AWS error.
die()  { log "ERROR: $*"; exit 1; }

# Fail fast if a required CLI tool (e.g. aws) isn't installed.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found on PATH"
}

# Load key=value pairs from .env into this shell's environment.
load_env() {
  local env_file="$1"
  [ -f "$env_file" ] || die "${env_file} not found — copy .env.example to .env and fill in your assigned values"
  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

# Fail if a named variable is unset/empty in the loaded .env.
require_env() {
  local name="$1"
  local value="${!name:-}"
  [ -n "$value" ] || die "required variable ${name} is not set in .env"
}

# STUDENT_ID becomes part of every resource name/tag, so its format matters —
# lowercase alphanumeric/hyphen only, matching typical AWS naming rules.
validate_student_id() {
  [[ "$STUDENT_ID" =~ ^[a-z0-9]([a-z0-9-]{0,30}[a-z0-9])?$ ]] \
    || die "STUDENT_ID '${STUDENT_ID}' must be lowercase alphanumeric/hyphen (your assigned sandbox prefix)"
}

# Basic sanity check that AWS_REGION looks like a real region code, not a
# region *name* (e.g. catches typing "Ireland" instead of "eu-west-1").
validate_region() {
  [[ "$AWS_REGION" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]] \
    || die "AWS_REGION '${AWS_REGION}' doesn't look like a real AWS region code"
}

# Restrict INSTANCE_TYPE to a small allow-list so a typo in .env can't
# accidentally launch something expensive against the $20 budget.
validate_instance_type() {
  case "$INSTANCE_TYPE" in
    t2.micro|t2.small|t3.micro|t3.small) ;;
    *) die "INSTANCE_TYPE '${INSTANCE_TYPE}' is outside the allowed list (t2/t3 micro|small) — kept small to protect the \$20 budget" ;;
  esac
}

# Run every required-variable and format check in one call — called first
# thing in every script's main().
validate_config() {
  for var in STUDENT_ID AWS_REGION AWS_PROFILE INSTANCE_TYPE COST_CENTER ENVIRONMENT_TAG OWNER_TAG; do
    require_env "$var"
  done
  validate_student_id
  validate_region
  validate_instance_type
}

# Thin wrapper so every AWS CLI call in these scripts consistently targets the
# right profile/region without repeating both flags everywhere. Also strips
# stray \r characters: on Windows, aws.exe emits \r\n line endings, but bash's
# $(...) only strips the trailing \n — leaving an invisible \r stuck to the
# end of captured values (e.g. corrupting "061051226504" into "061051226504\r",
# which then breaks anything built from it, like an IAM policy ARN). `tr` here
# still preserves aws's real exit code because `set -o pipefail` is active in
# every script that sources this file.
aws_cli() {
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" "$@" | tr -d '\r'
}

# Single source of truth for the naming convention: ${STUDENT_ID}-kente-<suffix>.
# Keeping this in one place means provision/cleanup/iam-setup can never disagree
# on what a given resource is called.
resource_name() {
  # $1: suffix, e.g. "sg" / "app-server" / "app-config"
  printf '%s-kente-%s' "$STUDENT_ID" "$1"
}

# Builds the --tag-specifications value applying the cost-center/environment/
# owner taxonomy (plus Name) to a resource at creation time.
tag_spec() {
  # $1: ResourceType (instance|volume|security-group), $2: Name tag value
  printf 'ResourceType=%s,Tags=[{Key=Name,Value=%s},{Key=cost-center,Value=%s},{Key=environment,Value=%s},{Key=owner,Value=%s}]' \
    "$1" "$2" "$COST_CENTER" "$ENVIRONMENT_TAG" "$OWNER_TAG"
}
