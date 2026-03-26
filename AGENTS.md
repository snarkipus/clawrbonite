# AGENTS.md

## Purpose
This repo contains Bash scripts for backing up and restoring an OpenClaw /
OpenShell sandbox with git bundles and GitHub. There is no app build pipeline,
package manager, or formal test suite. Optimize for correctness, safety, and
minimal diffs; most changes affect scripts that may run on a host or sandbox.

## Repository Layout
- `scripts/carbonite-init.sh` - initialize Carbonite inside a sandbox
- `scripts/carbonite-restore.sh` - restore backup contents from host to sandbox
- `scripts/carbonite-cron-setup.sh` - register the recurring backup cron job
- `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` - operational assumptions and flows
- `README.md` - currently empty

## Source Of Truth
Prefer current script behavior and `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` over
inventing abstractions. This repo is small, procedural, and ops-focused.

## Cursor / Copilot Rules
No repository-specific editor instruction files currently exist:
- No `.cursor/rules/`
- No `.cursorrules`
- No `.github/copilot-instructions.md`

If any are added later, treat them as higher-priority guidance and update this
file to reflect them.

## Build Commands
There is no compile/build step in this repository. Useful checks:
```bash
bash -n scripts/carbonite-init.sh
bash -n scripts/carbonite-restore.sh
bash -n scripts/carbonite-cron-setup.sh
for f in scripts/*.sh; do bash -n "$f"; done
```

## Lint Commands
No linter is configured in-repo. If `shellcheck` is installed locally, use it.
```bash
shellcheck scripts/*.sh
shellcheck scripts/carbonite-init.sh
```

If `shellcheck` is unavailable, fall back to `bash -n` plus manual review.

## Test Commands
There is no committed automated unit or integration test suite. Available
verification is:
1. Bash syntax checks
2. Script-specific linting with `shellcheck`, if available
3. Manual review against the deployment guide
4. Live operational runs only when explicitly requested by the user

Check one changed script:
```bash
bash -n scripts/carbonite-cron-setup.sh
```

Check all scripts after multi-file changes:
```bash
for f in scripts/*.sh; do bash -n "$f"; done
```

## Single-Test Guidance
Because there is no formal test runner, a "single test" here means validating
one changed script in isolation. Examples:
```bash
bash -n scripts/carbonite-restore.sh
shellcheck scripts/carbonite-restore.sh
```

For behavior checks, use the smallest safe command that exercises only the path
you changed. Do not run restore, force-push, upload, cron registration, or
credential-writing flows unless the task explicitly requires live execution.

## Safe Verification Order
1. Read the full target script before editing
2. Make the smallest change that preserves existing behavior
3. Run `bash -n` on the changed script
4. Run `shellcheck` on the changed script if available
5. Re-read comments and user-facing output for consistency
6. Clearly say which commands were not executed live

## Style Baseline
Follow existing repo style unless the user asks for a broader refactor.
- Use `#!/bin/bash`, not `sh`
- Use `set -euo pipefail` near the top
- Keep scripts procedural and readable
- Prefer explicit variables over clever one-liners
- Preserve the current operator-facing `echo` banner style

## External Command Usage
There are no imports in Bash, but command dependencies should stay intentional.
- Prefer commands already used here: `git`, `grep`, `tar`, `du`, `wc`, `awk`, `sed`
- Reuse existing patterns before adding new dependencies
- Do not add Python/Node tooling unless explicitly requested
- Assume `openclaw` / `openshell` may be absent outside the intended environment

## Formatting
- Keep line length reasonable, but prefer clarity over aggressive wrapping
- Preserve blank lines between major script phases
- Use aligned comment banners only when matching surrounding style
- Prefer `$(...)` over backticks
- Keep multiline command formatting readable and stable in diffs

## Quoting And Expansion
- Quote variable expansions by default: `"$VAR"`
- Quote paths and user-provided arguments
- Use `${VAR:-}` for optional env vars under `set -u`
- Avoid unquoted globs unless pathname expansion is intended
- Be careful when looping over filenames; do not broaden matching casually

## Types And Variables
Shell has no static types, so use naming and guards to make intent clear.
- Use uppercase for constants and env-driven config: `REPO_URL`, `GH_PAT`
- Use descriptive locals for temporary values
- Use booleans as `true` / `false` strings, matching existing scripts
- Validate required inputs early and fail fast with a clear message

## Naming Conventions
- Script names use kebab-case with the `carbonite-` prefix
- Functions, if added, should use descriptive snake_case names
- Variable names should describe purpose, not trivia
- Keep helper command names operationally obvious

## Control Flow
- Prefer `case` for flag parsing
- Prefer early exits for invalid states
- Keep nesting shallow where practical
- Make idempotent behavior explicit in code and output

## Error Handling
- Fail loudly on true precondition errors
- Print actionable messages before exiting
- Use `WARN:` for recoverable paths, matching current style
- Guard destructive commands with explicit conditions
- If failure is acceptable, handle it intentionally with a guarded branch or `|| true`

## Safety Rules
- Treat `GH_PAT`, `.git-credentials`, identity files, and auth profiles as secrets
- Never commit real credentials or sandbox-specific secrets
- Be very cautious around `rm -rf`, `git push --force`, and restore/upload flows
- Do not change host-vs-sandbox assumptions unless the task is about that behavior
- Preserve the documented clean-sandbox precondition for restore

## Documentation Expectations
- Update `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` when behavior changes
- Keep comments focused on why a step exists
- Preserve valid user-facing command examples

## What Not To Invent
Unless explicitly requested, do not add:
- New frameworks or package managers
- A test harness that changes repo scope
- CI/CD configuration
- Broad style-only refactors across all scripts

## Preferred Agent Workflow
1. Read the target script and related deployment-guide section
2. Confirm whether it runs on host, in sandbox, or both
3. Make a minimal patch
4. Run `bash -n` on the changed script
5. Run `shellcheck` too, if available
6. Report behavior changes and what was not executed live

## Final Check Before Claiming Completion
Always report which of these you actually ran:
- `bash -n` on each changed script
- `shellcheck` on each changed script, if available
- any live operational command, only if explicitly requested

Do not claim a script is fully validated if you only performed static checks.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
