#!/bin/bash
# env-setup — recreate a local Carbonite env helper after sandbox rebuild
# Carbonite keeps this helper in the writable .openclaw-data tree.
#
# Usage: run once after carbonite-init.sh --continue, then edit/source it as needed.

set -euo pipefail

ENV_HELPER="$HOME/.openclaw-data/carbonite/env.sh"
mkdir -p "$(dirname "$ENV_HELPER")"

cat > "$ENV_HELPER" << 'EOF'
# Carbonite local env helper — source manually when needed.
# Provider-backed credentials such as GITHUB_TOKEN should normally come from
# the current sandbox runtime rather than being copied here from old restores.
# If provider-backed git transport is broken, you can temporarily uncomment the
# next line so Carbonite backup/init uses a one-shot in-memory git auth header.
# export GITHUB_TOKEN="github_pat_..."
export SEARXNG_URL="http://host.openshell.internal:8888"
EOF

echo "Created $ENV_HELPER"
echo "Source it manually when needed: . $ENV_HELPER"
