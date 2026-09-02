# Executive Summary

One page. Plain language — this goes to the CTO, not another engineer.

## What was provisioned

A small, self-service developer environment for the assigned "Junior Backend
Developer" persona working on the Kente inventory API: one `t3.micro` EC2
instance to run and test the API server, a security group controlling network
access to it (closed to all inbound traffic by default — nothing in the
persona's brief calls for remote access), and one S3 bucket for the app's
configuration and deployment artifacts. All three are created and torn down by
a single idempotent script, re-runnable without side effects or duplicates.

## Tagging taxonomy and rationale

Every resource carries four tags: `cost-center` (which budget line this
sandbox usage rolls up to), `environment` (`sandbox`, so it's never confused
with a production resource), `owner` (the individual accountable for it), and
`Name` (a human-readable label for the console). This is the minimum set that
lets Finance allocate spend correctly and lets anyone auditing the account
immediately answer "whose is this, what's it for, and is it safe to delete" —
without it, cost reports can't be broken down by team/project, and cleanup
becomes guesswork.

## IAM least-privilege reasoning

The developer persona can launch, stop, and terminate only their own
tagged development instances; read and write only one named configuration
bucket; view (not modify) their own security group; and read instance status
and logs for debugging. It explicitly cannot manage IAM, touch any other
bucket, or operate in any other region — each grant traces back to a specific
line in the persona's stated needs, and each deliberate omission is recorded
as such rather than left ambiguous. Live testing also surfaced (and fixed) two
real AWS IAM nuances: bulk "list/describe" actions can't be scoped by resource
tags the way actions on one specific resource can, and a tag-conditioned
permission can't be used to fix the very tag it depends on — both are
documented in `ASSUMPTIONS_LOG.md`.

## Cost against the $20 budget

Checked directly via Cost Explorer (`aws ce get-cost-and-usage`) on
2026-09-03: total unblended spend since the account was issued is
effectively $0 — a small EC2/S3 charge (~$0.006) is offset by a data-transfer
credit, netting to roughly zero. This was expected by design: the EC2
instance is a free-tier-eligible `t3.micro`, sized deliberately small and
enforced by input validation so a typo can't launch anything larger, and
total runtime across development/testing has been well under a day of actual
instance-hours. Massive margin against the $20 budget. Cost Explorer data
lags about 24 hours behind actual usage, so this will be re-checked once
more immediately before final teardown to catch anything from the last day
of activity.

## Teardown confirmation

`cleanup.sh` reverses provisioning in dependency order (instance terminated
and confirmed stopped before its security group is deleted; the S3 bucket is
emptied before it's deleted) and then independently re-checks all three
resource types itself — it does not just trust that the delete calls
succeeded. A `Verified: zero resources remain` line only prints once all
three checks confirm nothing is left; this has already been proven once
during development, and will be re-run for the final teardown ahead of the
cohort deadline.

## Value-add feature

A tag/cost-compliance check runs every 5 minutes via cron (WSL, systemd-backed)
against the provisioned resources, using a dedicated long-lived IAM user
credential scoped to exactly this task rather than the broader bootstrap
role. When it finds a tag that's drifted from what it should be, it doesn't
just report the problem — it automatically fixes it, and only falls back to
"needs a human" when the drift is something its own least-privilege scope
correctly can't touch (see the IAM reasoning above). This directly protects
the accuracy of cost-allocation reporting — the CTO's stated reason for
wanting tagging in the first place — without adding any manual audit work.
