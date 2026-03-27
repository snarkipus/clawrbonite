# Carbonite Restore Upload Handling Design

## Problem

`openshell sandbox upload` appears to preserve layout when uploading a directory,
but wraps single files into same-named directories. In practice that turns
expected files such as `~/carbonite-init.sh` into paths like
`~/carbonite-init/carbonite-init.sh`, which breaks the documented restore flow.

## Constraints

- `scripts/carbonite-restore.sh` is host-only
- Restore must continue to assume a clean sandbox target
- The fix should avoid destructive cleanup inside `/sandbox`
- Validation in-repo is limited to static checks; runtime confirmation requires
  an operator-run restore drill

## Options Considered

### 1. Upload the restore tree as a directory

Use one directory-level upload instead of per-file uploads.

- Pros: smallest change, matches observed working behavior, preserves layout for
  both regular files and dotfiles
- Cons: depends on directory-upload semantics continuing to behave correctly

### 2. Upload a tarball and extract in sandbox

Package the restore tree on the host, upload one archive, then extract later.

- Pros: explicit layout control
- Cons: changes operator workflow, requires extra steps or remote execution

### 3. Keep per-file uploads and special-case destinations

- Pros: stays close to current script
- Cons: brittle, still tied to broken single-file semantics

## Decision

Adopt option 1. Change `scripts/carbonite-restore.sh` to upload the cloned
restore tree as one directory payload rooted at `/sandbox`, and update operator
messaging/docs only as needed to reflect that behavior.

## Verification Plan

- Run `bash -n scripts/carbonite-restore.sh`
- Run `shellcheck scripts/carbonite-restore.sh` if available
- Operator runs a restore drill and confirms top-level files and dotfiles land at
  the intended paths in the sandbox home directory
