# Persona Brief — Self-Authored

**Status: self-authored, not received from the instructor.** The lab README states
this file "will be added to your clone/remote before the lab opens." As of
2026-09-02, over a week after sandbox credentials were issued, it had not been
provided and no remote repository link was given either — see
`docs/ASSUMPTIONS_LOG.md` for the full timeline and the clarifying questions this
raised. Rather than leave the IAM policy and application config blocked
indefinitely, this brief was authored using the same reasoning the lab's own
brief describes for the CTO's "deliberately ambiguous requirement": design the
least-privilege policy myself, justify every permission, and record the
reasoning rather than wait indefinitely.

This started as a practice stand-in (see git history / prior commits referencing
"PRACTICE_PERSONA_BRIEF.md") and is promoted here to the real, final input for
this submission once it became clear the real brief would not arrive in time.

## Persona: Junior Backend Developer

Working on Kente Retail's inventory API, dev/test environment only.

### What they need to do day-to-day
- Launch, stop, and terminate their own EC2 dev instances to test the API server.
- Read/write objects in a single S3 bucket used for app config and deployment
  artifacts (not any other bucket).
- View (not modify) the security group attached to their own instance.
- Check basic instance status/logs while debugging.

### What they explicitly do NOT need
- No IAM management (can't create/modify users, groups, roles, policies).
- No access to other developers' resources or other AWS accounts/regions.
- No production resources — dev/test tagged resources only.

## Application-config requirements list

- `app_name`: kente-inventory-api
- `environment`: dev
- `port`: 8080
- `log_level`: info
- `database.host`: placeholder, injected via env var at deploy time (never hardcoded)
- `database.port`: 5432
- `database.name`: kente_inventory_dev
- `feature_flags.enable_new_checkout`: false
- `aws.region`: eu-west-1
- `aws.s3_config_bucket`: magnifique-kente-app-config (the bucket `scripts/provision.sh` creates)
