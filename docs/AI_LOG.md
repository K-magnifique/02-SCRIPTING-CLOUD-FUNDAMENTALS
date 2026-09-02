# AI Log

AI use is permitted and must be logged — it is never penalized on its own. You are
assessed on whether you can defend, verify, and correct what an AI tool produced.
Thoughtful rejection of AI output scores higher than blind acceptance.

Add one entry per session you use an AI tool, even briefly.

## Entry template (copy for each session)

- **Date:**
- **Tool:**
- **Prompt(s) used:**
- **What was accepted:**
- **What was rejected or changed, and why:**

## Entries

- **Date:** 2026-08-02 to 2026-08-25 (multi-session)
- **Tool:** Claude Code (Sonnet 5), VS Code extension
- **Prompt(s) used:** Asked it to read the lab brief (`doc.pdf`), the starter
  README, and the AWS sandbox access doc, and summarize what the lab actually
  requires; asked for help configuring a separate AWS CLI profile for bootstrap
  credentials instead of root; asked it to design and practice a least-privilege
  IAM policy against a stand-in persona since `PERSONA_BRIEF.md` never arrived;
  asked it to draft the idempotent provisioning script (security group, EC2,
  S3, tagging).
- **What was accepted:** The `LAB_REQUIREMENTS.md` summary and deliverables
  checklist; the recommendation to never use root and to create a named
  `amalitech-sandbox` profile instead; the requirement→action→resource mapping
  method for the IAM policy (verified myself via
  `iam:SimulatePrincipalPolicy` and real allow/deny tests against a live
  practice IAM user, not just taken on faith); the provisioning script's
  structure (`.env`-driven config, idempotent describe-before-create checks,
  dynamic AMI lookup, tag taxonomy).
- **What was rejected or changed, and why:** Rejected letting the assistant run
  AWS-CLI commands that would touch credentials or mutate the sandbox directly
  — typed and ran those myself in my own terminal instead, so nothing secret
  ever entered the chat transcript and so I actually understand every command
  well enough to defend it live. Corrected an early assumption that I was on
  root credentials once — the AI first flagged a root ARN, and it turned out to
  be right (had configured no profile yet); separately corrected a region typo
  ("Ireland" instead of the actual AWS region code `eu-west-1`) that I made,
  not something the AI got wrong. Have not yet accepted the IAM policy or app
  config as final — both remain practice-only pending the real
  `PERSONA_BRIEF.md`, deliberately not submitted as-is.
