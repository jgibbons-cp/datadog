#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Renders the whole source tree into ./.rendered with DEMO_NAME and DEMO_BRAND
# substituted, for the Docker Compose path.
#
#   ./render.sh
#   docker compose -f .rendered/docker-compose.yml --env-file .env up -d --build
#
# The Kubernetes path does this internally -- k8s/deploy.sh renders to a temp
# directory, so you do not need to run this first.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

[[ -f .env ]] || { echo "ERROR: no .env file. cp .env.example .env" >&2; exit 1; }
set -a; source .env; set +a
: "${DEMO_NAME:?set DEMO_NAME in .env}"
: "${DEMO_BRAND:?set DEMO_BRAND in .env}"

esc() { printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'; }
NAME_ESC="$(esc "$DEMO_NAME")"
BRAND_ESC="$(esc "$DEMO_BRAND")"

rm -rf .rendered
mkdir -p .rendered
tar --exclude='./.git' --exclude='./.env' --exclude='./.rendered' -cf - . | (cd .rendered && tar -xf -)

find .rendered -type f \( -name '*.sql' -o -name '*.sh'  -o -name '*.yaml' -o -name '*.yml' \
                       -o -name '*.js'  -o -name '*.py'  -o -name '*.java' -o -name '*.html' \
                       -o -name '*.json' -o -name '*.xml' -o -name '*.conf' -o -name '*.css' \
                       -o -name 'Dockerfile' \) -print0 \
  | xargs -0 sed -i.tokbak -e "s|__DEMO_NAME__|${NAME_ESC}|g" -e "s|__DEMO_BRAND__|${BRAND_ESC}|g"
find .rendered -name '*.tokbak' -delete

if grep -rq '__DEMO_' .rendered/db .rendered/services .rendered/loadgen 2>/dev/null; then
  echo "ERROR: placeholders survived rendering" >&2
  grep -rn '__DEMO_' .rendered/db .rendered/services .rendered/loadgen >&2
  exit 1
fi

cat <<EOF

Rendered './.rendered' for '${DEMO_BRAND}' (${DEMO_NAME}).

  docker compose -f .rendered/docker-compose.yml --env-file .env up -d --build

EOF
