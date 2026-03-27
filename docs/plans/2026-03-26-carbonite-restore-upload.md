# Carbonite Restore Upload Handling Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make host-side restore preserve the intended sandbox file layout by avoiding broken single-file upload semantics.

**Architecture:** Replace the current per-item upload loop in `scripts/carbonite-restore.sh` with one directory-level upload that stages the cloned Carbonite tree into `/sandbox`. Keep the existing clean-sandbox assumption, host-only behavior, and operator messaging intact unless the flow needs a small doc update.

**Tech Stack:** Bash, `openshell` CLI, git, deployment guide markdown

---

### Task 1: Update restore upload strategy

**Files:**
- Modify: `scripts/carbonite-restore.sh`

**Step 1: Write the failing test**

This repo has no formal test harness for shell behavior. Use a regression target
based on the known bad behavior: the current code uploads files one-by-one and
therefore produces wrapped paths like `~/carbonite-init/carbonite-init.sh`.

Document the regression target in the code change itself by removing the per-item
loop and replacing it with a single directory upload.

**Step 2: Run test to verify it fails**

Run:

```bash
bash -n scripts/carbonite-restore.sh
```

Expected: PASS syntax, but behavior remains known-bad by inspection because the
script still loops over `for item in * .[!.]*; do` and uploads single items.

**Step 3: Write minimal implementation**

Update `scripts/carbonite-restore.sh` to:

- keep cloning into `${TMPDIR}/carbonite`
- remove `${TMPDIR}/carbonite/.git`
- upload `${TMPDIR}/carbonite` once instead of iterating over top-level items
- keep operator-facing output explicit about source and destination

**Step 4: Run test to verify it passes**

Run:

```bash
bash -n scripts/carbonite-restore.sh
```

Expected: PASS with no syntax errors.

If available, also run:

```bash
shellcheck scripts/carbonite-restore.sh
```

Expected: no new shellcheck findings introduced by the edit.

**Step 5: Commit**

```bash
git add scripts/carbonite-restore.sh
git commit -m "fix: preserve restore layout during sandbox upload"
```

### Task 2: Update restore documentation if needed

**Files:**
- Modify: `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md`

**Step 1: Write the failing test**

Review the restore section and confirm whether it still accurately describes the
operator-visible flow after the script change.

**Step 2: Run test to verify it fails**

Run a manual docs check against the changed script.

Expected failure condition: the guide still implies per-file upload semantics or
omits an operator-visible detail needed for restore drills.

**Step 3: Write minimal implementation**

If needed, update the restore section to mention directory-level upload behavior
or any changed verification note. Avoid expanding scope beyond this issue.

**Step 4: Run test to verify it passes**

Re-read the updated guide alongside `scripts/carbonite-restore.sh`.

Expected: script and guide no longer disagree about restore behavior.

**Step 5: Commit**

```bash
git add CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md
git commit -m "docs: clarify restore upload behavior"
```

### Task 3: Verify and hand off

**Files:**
- Modify: `scripts/carbonite-restore.sh`
- Modify: `CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md` if needed

**Step 1: Run verification**

Run:

```bash
bash -n scripts/carbonite-restore.sh
```

If available, run:

```bash
shellcheck scripts/carbonite-restore.sh
```

**Step 2: Record runtime verification needs**

Document that an operator should run a restore drill and verify top-level files
and dotfiles now land directly in the sandbox home directory.

**Step 3: Commit**

```bash
git add scripts/carbonite-restore.sh CARBONITE-BACKUP-DEPLOYMENT-GUIDE.md docs/plans/2026-03-26-carbonite-restore-upload-design.md docs/plans/2026-03-26-carbonite-restore-upload.md
git commit -m "fix: preserve restore upload layout"
```
