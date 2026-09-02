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

- **Date:** 2026-08-26 to 2026-09-02 (multi-session)
- **Tool:** Claude Code (Sonnet 5), VS Code extension
- **Prompt(s) used:** Walked through `cleanup.sh` function-by-function with the
  AI explaining the reasoning first, typing each function into the file myself
  rather than having it write the file; asked for a defense-walkthrough
  rehearsal script with runnable commands; after confirming `PERSONA_BRIEF.md`
  and a remote repo link still hadn't arrived after over a week, asked the AI
  to help finalize the decision to self-author the persona brief as the real
  submission input instead of continuing to wait.
- **What was accepted:** The explanations of each `cleanup.sh` function (why
  teardown order is the reverse of creation order, why `verify_clean` checks
  each resource independently rather than trusting the delete calls); the
  `.gitignore` bug fix it caught (`.env.*` was also swallowing the committed
  `.env.example` template); promoting the already-practiced persona to
  `PERSONA_BRIEF.md` as final, with the reasoning documented in
  `ASSUMPTIONS_LOG.md` rather than silently treated as equivalent to a real
  brief.
- **What was rejected or changed, and why:** Rejected having the AI write
  `cleanup.sh` directly — typed each function in myself instead, and caught
  (with the AI's help re-reading the file) that I'd accidentally duplicated
  `delete_security_group` and skipped `empty_and_delete_bucket` on a first
  pass; fixed by re-typing rather than accepting a generated replacement.
  Rejected an early Bash tool call proposing to run `mkdir`/AWS profile checks
  automatically — chose to run AWS-touching commands myself throughout, so
  nothing credential-related ever needed to pass through the assistant.
