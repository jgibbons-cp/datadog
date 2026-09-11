#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Registers the Software Catalog entity definitions with Datadog.
# Requires DD_API_KEY and DD_APP_KEY in .env (the app key is only needed here).
# Safe to re-run -- registration is an upsert keyed on entity name.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! \033[0m%s\n' "$*"; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f .env ]] || die "No .env file."
set -a; source .env; set +a

[[ -n "${DD_API_KEY:-}" ]] || die "DD_API_KEY is not set in .env"
[[ -n "${DD_APP_KEY:-}" ]] || die "DD_APP_KEY is not set in .env. Create one at
  Organization Settings -> Application Keys. It is only needed for this script."

SITE="${DD_SITE:-datadoghq.com}"
ENDPOINT="https://api.${SITE}/api/v2/catalog/entity"
SOURCE="k8s/catalog/entities.yaml"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Split the multi-document YAML into one file per entity.
awk -v dir="$WORK" '
  /^---[[:space:]]*$/ { n++; next }
  { print > sprintf("%s/entity-%02d.yaml", dir, n) }
' n=0 "$SOURCE"

say "Registering entities with ${ENDPOINT}"
ok=0; failed=0
for file in "$WORK"/entity-*.yaml; do
  name=$(grep -m1 '^  name:' "$file" | awk '{print $2}')
  status=$(curl -sS -o "$WORK/response.txt" -w '%{http_code}' -X POST "$ENDPOINT" \
    -H "Accept: application/json" \
    -H "Content-Type: application/yaml" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
    --data-binary "@${file}")

  if [[ "$status" == 2* ]]; then
    printf '  \033[1;32mok\033[0m    %s\n' "$name"
    ok=$((ok + 1))
  else
    printf '  \033[1;31mfail\033[0m  %s (HTTP %s)\n' "$name" "$status"
    head -c 300 "$WORK/response.txt"; echo
    failed=$((failed + 1))
  fi
done

say "Registered ${ok} entities, ${failed} failed."
if (( failed > 0 )); then
  warn "If the API rejected the payload, you can still import the definitions"
  warn "by hand: Software Catalog -> Add Entity -> Import YAML, using"
  warn "  ${SOURCE}"
fi

cat <<EOF

  Software Catalog   https://app.${SITE}/services
  Filter by team     team:__DEMO_NAME__-storefront, team:__DEMO_NAME__-commerce, team:__DEMO_NAME__-data

  Note: teams must exist in Datadog (Organization Settings -> Teams) for
  ownership to resolve to a real team page. The tags work regardless.

EOF
