#!/bin/bash
# websearch — query the OpenShell-hosted SearXNG sidecar from inside a sandbox

set -euo pipefail

SEARXNG_URL="${SEARXNG_URL:-http://host.openshell.internal:8888}"
COUNT=5
CATEGORY="general"
QUERY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --count)
      COUNT="$2"
      shift 2
      ;;
    --category)
      CATEGORY="$2"
      shift 2
      ;;
    *)
      QUERY="${QUERY:+$QUERY }$1"
      shift
      ;;
  esac
done

if [ -z "$QUERY" ]; then
  echo "Error: No search query provided"
  echo "Usage: websearch <query> [--count N] [--category CATEGORY]"
  exit 1
fi

RESULT=$(python3 -c '
import json
import sys
import urllib.parse
import urllib.request

base_url, query, category = sys.argv[1:4]
params = urllib.parse.urlencode({"q": query, "format": "json", "categories": category})
url = f"{base_url.rstrip("/")}/search?{params}"
with urllib.request.urlopen(url, timeout=15) as response:
    sys.stdout.write(response.read().decode("utf-8"))
' "$SEARXNG_URL" "$QUERY" "$CATEGORY")

python3 -c '
import json, sys

try:
    data = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print("Error: Invalid JSON response")
    sys.exit(1)

results = data.get("results", [])
count = int(sys.argv[2])
query = sys.argv[3]

if not results:
    print(f"No results found for: {query}")
    sys.exit(0)

print(f"Found {len(results)} results for: {query}")
print(f"Showing top {min(count, len(results))}:")
print()

for i, result in enumerate(results[:count], start=1):
    title = result.get("title", "No title")
    url = result.get("url", "")
    content = result.get("content", "No description")
    engines = ", ".join(result.get("engines", []))
    score = result.get("score", 0)
    print(f"[{i}] {title}")
    print(f"    URL: {url}")
    print(f"    {content}")
    print(f"    Engines: {engines} | Score: {score:.1f}")
    print()
' "$RESULT" "$COUNT" "$QUERY"
