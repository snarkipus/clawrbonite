#!/bin/bash
# =============================================================================
# carbonite-bundle — Freeze/thaw nested git repos for Carbonite backup
# =============================================================================
# Nested git repos (like OpenClaw's workspace) prevent `git add -A` from
# working because git interprets them as submodules. This script converts
# them to/from portable .bundle files using `git bundle`.
#
# Usage:
#   carbonite-bundle freeze    # .git dirs → .carbonite.bundle files
#   carbonite-bundle thaw      # .carbonite.bundle files → .git dirs
#   carbonite-bundle status    # show nested repos and bundle state
# =============================================================================

set -euo pipefail

CARBONITE_REPO_ROOT="$HOME/.openclaw-data"

cd "$CARBONITE_REPO_ROOT"

ACTION="${1:-status}"

# Find nested .git directories (exclude Carbonite's own top-level .git)
find_nested_gits() {
  find . -mindepth 2 -name ".git" -type d \
    ! -path "./.git/*" \
    2>/dev/null
}

# Find .carbonite.bundle files (and tar fallbacks)
find_bundles() {
  find . \( -name ".carbonite.bundle" -o -name ".carbonite.bundle.tar" \) \
    -type f \
    ! -path "./.git/*" \
    2>/dev/null
}

case "$ACTION" in
  freeze)
    echo "[carbonite-bundle] Freezing nested git repos..."
    FOUND=0
    while IFS= read -r gitdir; do
      PARENT=$(dirname "$gitdir")
      BUNDLE="${PARENT}/.carbonite.bundle"

      echo "  → ${PARENT}/"

      # Create bundle from the nested repo (captures full history)
      if git -C "$PARENT" bundle create "${BUNDLE}.tmp" --all 2>/dev/null; then
        mv "${BUNDLE}.tmp" "$BUNDLE"
        SIZE=$(du -sh "$BUNDLE" | cut -f1)
        echo "    Bundled (${SIZE})"
        FOUND=$((FOUND + 1))
      else
        # Bundle fails on repos with no commits — fall back to tar
        echo "    WARN: git bundle failed (no commits?), using tar fallback"
        if tar -cf "${PARENT}/.carbonite.bundle.tar" -C "$PARENT" .git 2>/dev/null; then
          FOUND=$((FOUND + 1))
          echo "    Tar fallback created"
        else
          echo "    ERROR: Could not archive ${PARENT}/.git"
          continue
        fi
      fi

      # Move .git out of the way so git add -A won't hit submodule detection.
      # .gitignore (**/.git) handles subsequent runs, but the initial git add
      # on a fresh repo triggers submodule detection BEFORE reading .gitignore.
      mv "${PARENT}/.git" "${PARENT}/.git.frozen"
      echo "    Moved .git → .git.frozen"
    done < <(find_nested_gits)

    if [ "$FOUND" -eq 0 ]; then
      echo "  No nested git repos found."
    else
      echo "  Froze ${FOUND} nested repo(s)."
    fi
    ;;

  thaw)
    echo "[carbonite-bundle] Thawing bundles back to git repos..."
    FOUND=0
    while IFS= read -r bundle; do
      PARENT=$(dirname "$bundle")
      BASENAME=$(basename "$bundle")

      echo "  → ${PARENT}/"

      # Skip if .git already exists and is populated
      if [ -d "${PARENT}/.git" ] && [ -f "${PARENT}/.git/HEAD" ]; then
        echo "    .git already exists, skipping"
        continue
      fi

      if [[ "$BASENAME" == *.tar ]]; then
        # Tar fallback — extract directly
        if tar -xf "$bundle" -C "$PARENT" 2>/dev/null; then
          echo "    Restored from tar fallback"
          rm -f "$bundle"
          rm -rf "${PARENT}/.git.frozen" 2>/dev/null
        else
          echo "    ERROR: Could not extract tar bundle"
        fi
      else
        # ── Standard thaw: init → fetch → checkout → reset ──────────────
        # This follows the idiomatic git pattern for materializing a repo
        # from a bundle into an existing directory with working tree files.

        # Clean any partial .git state
        rm -rf "${PARENT}/.git"

        # Initialize a fresh repo in the workspace directory
        git -C "$PARENT" init -q

        # Add the bundle as a temporary remote and fetch refs into tracking namespace
        git -C "$PARENT" remote add carbonite "$bundle"
        git -C "$PARENT" fetch -q carbonite "+refs/heads/*:refs/remotes/carbonite/*" 2>/dev/null
        git -C "$PARENT" fetch -q carbonite "+refs/tags/*:refs/tags/*" 2>/dev/null || true

        # Resolve the default branch from the bundle's HEAD
        DEFAULT_REF=$(git ls-remote --symref "$bundle" HEAD 2>/dev/null \
                      | awk '/^ref:/ {print $2}' \
                      | sed 's#refs/heads/##')
        [ -z "$DEFAULT_REF" ] && DEFAULT_REF="main"

        # Checkout the resolved branch from remote-tracking refs, or detach as fallback
        if git -C "$PARENT" show-ref --verify -q "refs/remotes/carbonite/$DEFAULT_REF" 2>/dev/null; then
          git -C "$PARENT" checkout -q -B "$DEFAULT_REF" "refs/remotes/carbonite/$DEFAULT_REF" 2>/dev/null
        else
          # No matching branch — detach to whatever FETCH_HEAD points at
          git -C "$PARENT" checkout -q --detach FETCH_HEAD 2>/dev/null || true
        fi

        # Hard reset to align index + working tree with HEAD
        git -C "$PARENT" reset --hard -q 2>/dev/null || true

        # Remove the temporary remote
        git -C "$PARENT" remote remove carbonite 2>/dev/null || true

        # Clean up frozen .git from freeze step (if present)
        rm -rf "${PARENT}/.git.frozen" 2>/dev/null

        # ── Post-thaw validation ────────────────────────────────────────
        THAW_OK=true
        if ! git -C "$PARENT" rev-parse --is-inside-work-tree &>/dev/null; then
          echo "    WARN: not recognized as a work tree after thaw"
          THAW_OK=false
        fi

        HEAD_REF=$(git -C "$PARENT" symbolic-ref -q HEAD 2>/dev/null \
                   || git -C "$PARENT" rev-parse --short HEAD 2>/dev/null \
                   || echo "NONE")
        PORCELAIN=$(git -C "$PARENT" status --porcelain 2>/dev/null | wc -l)
        LAST_MSG=$(git -C "$PARENT" log -1 --format="%s" 2>/dev/null || echo "n/a")

        if [ "$THAW_OK" = true ]; then
          echo "    Restored (HEAD: ${HEAD_REF}, dirty: ${PORCELAIN}, last: ${LAST_MSG})"
        else
          echo "    WARN: Thaw completed but validation failed — repo may need manual repair"
        fi

        rm -f "$bundle"
      fi
      FOUND=$((FOUND + 1))
    done < <(find_bundles)

    if [ "$FOUND" -eq 0 ]; then
      echo "  No bundles found to thaw."
    fi
    ;;

  status)
    echo "[carbonite-bundle] Nested git repos:"
    GITS=0
    while IFS= read -r gitdir; do
      PARENT=$(dirname "$gitdir")
      BRANCH=$(git -C "$PARENT" branch --show-current 2>/dev/null || echo "detached/empty")
      COMMITS=$(git -C "$PARENT" rev-list --count HEAD 2>/dev/null || echo "0")
      echo "  ${PARENT}/ (branch: ${BRANCH}, commits: ${COMMITS})"
      GITS=$((GITS + 1))
    done < <(find_nested_gits)
    if [ "$GITS" -eq 0 ]; then
      echo "  (none)"
    fi

    echo ""
    echo "[carbonite-bundle] Existing bundles:"
    BUNDLES=0
    while IFS= read -r bundle; do
      echo "  ${bundle} ($(du -sh "$bundle" | cut -f1))"
      BUNDLES=$((BUNDLES + 1))
    done < <(find_bundles)
    if [ "$BUNDLES" -eq 0 ]; then
      echo "  (none)"
    fi
    ;;

  *)
    echo "Usage: carbonite-bundle {freeze|thaw|status}"
    exit 1
    ;;
esac
