# Kente Retail — First Cloud Footprint

Starter repo for the "First Cloud Footprint" lab. This is the repo you'll build your
submission in — commit to it as you go, not just at the end (commit cadence and
messages are part of Process Evidence in the rubric).

## What you're given

- This README and the `docs/` templates below.
- A `PERSONA_BRIEF.md` will be added to your clone/remote before the lab opens — it
  describes your assigned developer persona and your application-config requirements
  list. There is no starter YAML/JSON template: you author both files yourself from
  that requirements list.
- See `aws-sandbox-account-access.md` (one level up, alongside this repo) for how to
  get AWS sandbox credentials.

## What you build (deliverables checklist)

Track your own progress — none of this is provided as a template:

- [ ] Provisioning script — idempotent Bash: functions, error handling, input
      validation. Provisions an EC2 instance, a security group, and an S3 bucket.
      Re-running it must not error and must not create duplicates.
- [ ] IAM policy definition — least-privilege user/group/policy for your assigned
      persona. Every permission needs a one-line justification. No unjustified
      wildcard actions or resources.
- [ ] Application configuration — YAML **and** JSON, hand-authored from your
      `PERSONA_BRIEF.md` requirements list, matching content between the two formats.
      No plaintext secrets — use environment-variable placeholders. Validate the JSON
      with `jq`.
- [ ] Resource-tagging taxonomy — at minimum `cost-center`, `environment`, `owner` —
      applied to every resource your script creates, with a short written
      justification for the taxonomy you chose.
- [ ] Scheduled automation — a cron job or systemd timer running a recurring task
      against your provisioned resources (e.g. a cost/tag-compliance check or a
      status report).
- [ ] Cleanup script — tears everything down, and you can prove (console check or
      CLI query) that zero resources remain.
- [ ] `docs/EXECUTIVE_SUMMARY.md` — one page.
- [ ] `docs/ASSUMPTIONS_LOG.md` — filled in as you go, not written retroactively.
- [ ] `docs/AI_LOG.md` — every session you use an AI tool, even briefly.
- [ ] `docs/INCIDENT_REPORT.md` — after the Day-2 incident during your walkthrough.

## Budget

Target spend for the whole exercise: **under $20**. There's a hard teardown deadline —
your instructor will confirm the exact date/time for your cohort. Cost Explorer data
lags about 24 hours behind actual usage, so don't wait until the deadline to check your
running total.

## A note on the Day-2 incident

Something in your environment will change without warning during your defense
walkthrough. That's expected — see `docs/INCIDENT_REPORT.md` for the template you'll
fill in once it happens.
