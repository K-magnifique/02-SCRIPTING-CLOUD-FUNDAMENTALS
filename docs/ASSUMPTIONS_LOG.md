# Assumptions Log

Keep this updated as you work, not written retroactively the night before your
walkthrough — the instructor can tell the difference.

## Developer persona — access needs beyond what the brief states outright

- **`PERSONA_BRIEF.md` was never delivered.** As of 2026-08-25, no persona brief or
  requirements list has appeared in `starter-repo/` (checked repeatedly across the
  build). Rather than block entirely, I built a fictional stand-in persona
  ("Junior Backend Developer" / jbdev — see `PRACTICE_PERSONA_BRIEF.md` at the
  project root, outside this repo so it can't be mistaken for the real submission)
  and used it to practice the actual method: map each stated need to a specific
  AWS action + resource, write the policy, then verify with
  `iam:SimulatePrincipalPolicy` that everything *not* stated is denied.
- Practiced granting: launch/stop/terminate own tagged EC2 instances,
  read/write in exactly one named S3 bucket, read-only security-group
  visibility, and log/status read access for debugging — each with a `Sid`
  naming its justification. Deliberately withheld: IAM management, any other
  bucket, any other region, production resources — proven denied via
  simulation rather than just assumed.
- **2026-09-02 — decision: self-author the persona brief as final, not
  practice.** Over a week after sandbox credentials were issued, `PERSONA_BRIEF.md`
  still had not been delivered and no remote repo link had been provided either.
  Rather than continue blocking the IAM policy and app config indefinitely, the
  practice persona above was promoted, unchanged in substance, to
  `starter-repo/PERSONA_BRIEF.md` as the real input for this submission — see
  that file's own header for the reasoning. The real IAM policy is now authored
  against real resource names (`STUDENT_ID=magnifique`, e.g.
  `magnifique-kente-app-config`), not the `practice-jbdev` placeholders; the
  old practice IAM user/group/policy and S3 bucket get deleted from the sandbox
  once the real ones are confirmed working, so nothing ambiguous is left for a
  reviewer to trip over.

## Clarifying questions you'd ask the CTO in a real engagement

- Which exact tag key does the AWS Budget alarm actually filter on? The sandbox
  doc says it's "configured on your cost-allocation tag" without naming the key —
  I assumed `cost-center`, but in a real engagement I'd confirm this before
  trusting the tripwire to catch anything.
- Does this persona need any remote-access method (SSH, SSM Session Manager) at
  all? Nothing in scope yet says so, so the provisioning script currently leaves
  the security group closed to all inbound traffic by default.
- What is my actual assigned student/resource-naming prefix and region? The
  sandbox doc says these come bundled with bootstrap credential issuance; I
  received the credentials (resolving to `assumed-role/DCEPrincipal-dce/...` in
  account `061051226504`, region confirmed as `eu-west-1` since that's what
  `get-caller-identity` succeeded against) but no explicit prefix was stated
  alongside them, so `STUDENT_ID` in `.env.example` is a placeholder
  (`changeme`) pending confirmation or trial-and-error against `AccessDenied`
  errors, per the sandbox doc's own guidance.
- Is there a remote git repository I'm meant to push `starter-repo` to, or am I
  expected to create my own and share the link at submission time? Neither the
  README nor the lab platform surfaced one as of 2026-08-25.

## Other requirement gaps you filled in yourself

- **Config delivery mechanism**: introduced `.env` (git-ignored, `.env.example`
  committed) to hold `STUDENT_ID`, region, profile, instance size, and tag
  values, since the real values weren't available yet and hardcoding them would
  have blocked writing the provisioning script at all.
- **Naming convention**: `${STUDENT_ID}-kente-<purpose>` for every resource
  (security group, EC2 instance, S3 bucket), to satisfy the sandbox's
  "resource names/tags must start with your student identifier" scoping rule
  once the real identifier is known.
- **Instance sizing**: restricted `INSTANCE_TYPE` to a small allow-list
  (`t2/t3.micro|small`, default `t3.micro`) enforced by input validation in
  `scripts/lib/common.sh`, so a typo can't accidentally launch something
  expensive against the $20 budget.
- **AMI selection**: resolved dynamically via the public SSM parameter for the
  latest Amazon Linux 2023 AMI rather than hardcoding a region-specific AMI ID,
  so the script isn't silently wrong if the region changes.
- **Security-group default posture**: no inbound rules unless `ALLOWED_SSH_CIDR`
  is explicitly set in `.env` — chose secure-by-default over guessing at a
  remote-access requirement that isn't in scope yet.
- **Tag values**: `environment=sandbox`, `cost-center=kente-retail-lab`,
  `owner=${STUDENT_ID}` — reasonable defaults pending the clarifying question
  above about the Budget alarm's actual filter key.
- **Value-add feature (tag auto-remediation) — credential and permission design**:
  `status-report.sh` runs under a dedicated static IAM user credential
  (`magnifique-kente-persona`, the persona's own access key) rather than the
  bootstrap role, since an unattended cron job needs long-lived credentials and
  shouldn't run with more privilege than the check itself requires. Live testing
  (2026-09-02) surfaced a real IAM nuance worth recording: `ec2:CreateTags` was
  granted with a `Condition` requiring `aws:ResourceTag/owner == magnifique` —
  when I deliberately drifted the `owner` tag itself to prove remediation works,
  the persona could no longer fix that *specific* tag, because the condition
  evaluates against the resource's current tag state, and the very thing that
  was wrong was the condition's own input. Decided to keep this as-is rather
  than loosen the condition: a scoped credential being unable to reclaim
  ownership of a resource that's drifted away from it is a reasonable security
  boundary, not a bug — that kind of drift needs a human with the bootstrap
  role, and `status-report.sh` reports it clearly (`REMEDIATION FAILED --
  manual attention needed`) and exits non-zero (triggering cron's own
  mail-on-error) rather than silently failing or crashing the rest of the
  check.
- Also discovered live: EC2's `Describe*`/`List*` actions (e.g.
  `ec2:DescribeInstances`) don't support resource-level tag conditions the way
  actions on a single identified resource (`RunInstances`, `CreateTags`) do —
  combining them into one conditioned statement caused a real
  `UnauthorizedOperation`. Split into a separate unconditioned statement once
  the actual error surfaced, rather than assumed upfront.
