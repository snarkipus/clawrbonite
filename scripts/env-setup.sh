#!/bin/bash
# env-setup — recreate a local Carbonite env helper after sandbox rebuild
# Carbonite keeps this helper under the canonical writable .openclaw tree.
#
# Usage: run once after carbonite-init.sh --continue, then edit/source it as needed.

set -euo pipefail

ENV_HELPER="$HOME/.openclaw/carbonite/env.sh"
mkdir -p "$(dirname "$ENV_HELPER")"

if [ -f "$ENV_HELPER" ]; then
  echo "$ENV_HELPER already exists; leaving existing helper unchanged."
  echo "Edit it manually if you need to rotate sandbox-local Carbonite auth."
  exit 0
fi

cat > "$ENV_HELPER" << 'EOF'
# Carbonite local env helper — source manually when needed.
# Provider-backed credentials such as GITHUB_TOKEN should normally come from
# the current sandbox runtime rather than being copied here from old restores.
# If provider-backed git transport is broken, you can temporarily uncomment the
# next line so Carbonite backup/init uses a one-shot in-memory git auth header.
# export GITHUB_TOKEN="github_pat_..."
# websearch reads SEARXNG_URL from here when you want to point it at a non-default
# sidecar endpoint.
export SEARXNG_URL="http://host.openshell.internal:8888"

# Make Carbonite helpers available by command name after sourcing this file.
case ":$PATH:" in
  *":$HOME/.openclaw/carbonite/bin:"*) ;;
  *) export PATH="$HOME/.openclaw/carbonite/bin:$PATH" ;;
esac
EOF

echo "Created $ENV_HELPER"
echo "Source it manually when needed: . $ENV_HELPER"
