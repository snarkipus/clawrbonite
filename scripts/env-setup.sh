#!/bin/bash
# env-setup — recreate ~/.env after sandbox rebuild
# Carbonite backs up this template; the actual .env is gitignored.
#
# Usage: run once after carbonite-init.sh --continue, then fill in tokens.

set -euo pipefail

cat > ~/.env << 'EOF'
# Sandbox environment secrets — NOT tracked by Carbonite
# Fill in values after rebuild
export GITHUB_TOKEN=""
export SEARXNG_URL="http://host.openshell.internal:8888"
EOF

echo "Created ~/.env — edit it to add your tokens, then: source ~/.bashrc"
