#!/usr/bin/env bash
# Removes the demo from the cluster. Pass --cluster to delete the kind cluster too.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
[[ -f .env ]] && { set -a; source .env; set +a; }
: "${DEMO_NAME:?set DEMO_NAME in .env}"

say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }

if [[ "${1:-}" == "--cluster" ]]; then
  say "Deleting the kind cluster"
  kind delete cluster --name "$DEMO_NAME"
  exit 0
fi

say "Removing the Datadog Agent"
helm uninstall datadog -n datadog 2>/dev/null || true
kubectl delete namespace datadog --ignore-not-found --wait=true

say "Removing the $DEMO_NAME namespace (this deletes the PVCs and all seeded data)"
kubectl delete namespace "$DEMO_NAME" --ignore-not-found --wait=true
# delete returns before termination completes; a redeploy would then fail with
# "object is being deleted", so block until it is really gone.
kubectl wait --for=delete "namespace/$DEMO_NAME" --timeout=5m 2>/dev/null || true

say "Done. The kind cluster is still running -- add --cluster to delete it."
