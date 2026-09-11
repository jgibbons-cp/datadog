#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Builds the demo stack, loads it into a kind cluster, and installs the
# Datadog Agent. Safe to re-run.
#
# Everything is named from DEMO_NAME in .env -- cluster, namespace, service
# names, database identities and Datadog tags -- so two engineers can run this
# side by side without colliding.
# ---------------------------------------------------------------------------
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TAG=1.4.0

say()  { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! \033[0m%s\n' "$*"; }
die()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight
[[ -f .env ]] || die "No .env file. Run: cp .env.example .env  then edit it."
set -a; source .env; set +a

for required in DEMO_NAME DEMO_BRAND DD_API_KEY DD_SITE \
                MYSQL_ROOT_PASSWORD MYSQL_APP_PASSWORD MYSQL_DD_PASSWORD \
                POSTGRES_ROOT_PASSWORD POSTGRES_APP_PASSWORD POSTGRES_DD_PASSWORD; do
  [[ -n "${!required:-}" ]] || die "$required is not set in .env"
done
[[ "$DD_API_KEY" == replace_with* ]] && die "DD_API_KEY is still the placeholder in .env"
[[ "$DEMO_NAME" =~ ^[a-z][a-z0-9-]{1,20}$ ]] || \
  die "DEMO_NAME must be lowercase letters, digits and hyphens (it becomes a Kubernetes namespace)."

CLUSTER="$DEMO_NAME"
NS="$DEMO_NAME"

for tool in docker kind kubectl helm; do
  command -v "$tool" >/dev/null || die "$tool is not installed."
done
docker info >/dev/null 2>&1 || die "Docker daemon unreachable. Is Colima running? Try: colima start"

if [[ "${DD_RUM_APPLICATION_ID:-}" == replace_with* || -z "${DD_RUM_APPLICATION_ID:-}" ]]; then
  warn "DD_RUM_APPLICATION_ID is not set -- the storefront will load but RUM will produce nothing."
fi

say "Deploying '$DEMO_BRAND' as '$DEMO_NAME' (cluster and namespace: $DEMO_NAME)"

# --------------------------------------------------------------- templating
# Manifests carry __DEMO_NAME__ and __DEMO_BRAND__ placeholders. Rendered with
# sed rather than envsubst, so there is nothing extra to install on macOS and
# shell variables inside Job scripts are left untouched.
RENDERED="$(mktemp -d)"
trap 'rm -rf "$RENDERED"' EXIT
mkdir -p "$RENDERED/manifests"

esc() { printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'; }
NAME_ESC="$(esc "$DEMO_NAME")"
BRAND_ESC="$(esc "$DEMO_BRAND")"

render() {
  sed -e "s|__DEMO_NAME__|${NAME_ESC}|g" -e "s|__DEMO_BRAND__|${BRAND_ESC}|g" "$1" > "$2"
}

for f in k8s/manifests/*.yaml; do
  render "$f" "$RENDERED/manifests/$(basename "$f")"
done
render k8s/kind-cluster.yaml "$RENDERED/kind-cluster.yaml"

M="$RENDERED/manifests"

# The manifests are not the only place placeholders appear. SQL init scripts,
# application source and the RUM snippet all carry them too, and those are
# baked into images or mounted as ConfigMaps rather than applied through
# kubectl. Render the whole tree into a staging copy and build from that,
# otherwise MySQL seeds into a database called __DEMO_NAME___orders and RUM
# reports a service named __DEMO_NAME__-web-browser.
SRC="$RENDERED/src"
mkdir -p "$SRC"
tar --exclude='./.git' --exclude='./.env' --exclude='./.rendered' -cf - . | (cd "$SRC" && tar -xf -)

find "$SRC" -type f \( -name '*.sql' -o -name '*.sh'  -o -name '*.yaml' -o -name '*.yml' \
                     -o -name '*.js'  -o -name '*.py'  -o -name '*.java' -o -name '*.html' \
                     -o -name '*.json' -o -name '*.xml' -o -name '*.conf' -o -name '*.css' \
                     -o -name 'Dockerfile' \) -print0 \
  | xargs -0 sed -i.tokbak -e "s|__DEMO_NAME__|${NAME_ESC}|g" -e "s|__DEMO_BRAND__|${BRAND_ESC}|g"
find "$SRC" -name '*.tokbak' -delete

if grep -rq '__DEMO_' "$SRC/db" "$SRC/services" "$SRC/loadgen" 2>/dev/null; then
  die "placeholders survived rendering -- check bin/ and file extensions in deploy.sh"
fi

# ------------------------------------------------------------------ cluster
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  say "kind cluster '$CLUSTER' already exists"
else
  say "Creating kind cluster '$CLUSTER'"
  kind create cluster --config "$RENDERED/kind-cluster.yaml"
fi
kubectl config use-context "kind-$CLUSTER"

# ------------------------------------------------------------------- images
say "Building images"
docker build -t "$DEMO_NAME/orders:$TAG"  "$SRC/services/orders"
docker build -t "$DEMO_NAME/catalog:$TAG" "$SRC/services/catalog"
docker build -t "$DEMO_NAME/bff:$TAG"     "$SRC/services/bff"
docker build -t "$DEMO_NAME/web:$TAG"     "$SRC/services/web"
docker build -t "$DEMO_NAME/loadgen:$TAG" "$SRC/loadgen"

say "Loading images into kind"
for image in orders catalog bff web loadgen; do
  kind load docker-image "$DEMO_NAME/$image:$TAG" --name "$CLUSTER"
done

# ------------------------------------------------------- namespace + config
say "Applying namespace, secrets and init ConfigMaps"
kubectl apply -f "$M/00-namespace.yaml"

kubectl create secret generic "$DEMO_NAME-db" -n "$NS" \
  --from-literal=MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  --from-literal=MYSQL_APP_PASSWORD="$MYSQL_APP_PASSWORD" \
  --from-literal=MYSQL_DD_PASSWORD="$MYSQL_DD_PASSWORD" \
  --from-literal=POSTGRES_ROOT_PASSWORD="$POSTGRES_ROOT_PASSWORD" \
  --from-literal=POSTGRES_APP_PASSWORD="$POSTGRES_APP_PASSWORD" \
  --from-literal=POSTGRES_DD_PASSWORD="$POSTGRES_DD_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "$DEMO_NAME-datadog" -n "$NS" \
  --from-literal=DD_SITE="$DD_SITE" \
  --from-literal=DD_RUM_APPLICATION_ID="${DD_RUM_APPLICATION_ID:-}" \
  --from-literal=DD_RUM_CLIENT_TOKEN="${DD_RUM_CLIENT_TOKEN:-}" \
  --from-literal=DEMO_BRAND="$DEMO_BRAND" \
  --dry-run=client -o yaml | kubectl apply -f -

# The same init scripts the compose stack uses -- one source of truth.
kubectl create configmap mysql-init -n "$NS" \
  --from-file="$SRC/db/mysql/init/" --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap postgres-init -n "$NS" \
  --from-file="$SRC/db/postgres/init/" --dry-run=client -o yaml | kubectl apply -f -

# ----------------------------------------------------- data tier, then apps
# Two phases on purpose: application pods started during the seed crash-loop
# for its whole duration, which wastes time and pollutes the pod-restart views
# the demo is meant to show.
say "Starting the data tier"
kubectl apply -f "$M/10-redis.yaml" -f "$M/11-mysql.yaml" -f "$M/12-postgres.yaml"

say "Waiting for databases to seed (first run takes 5-15 minutes)"
kubectl rollout status statefulset/mysql    -n "$NS" --timeout=40m
kubectl rollout status statefulset/postgres -n "$NS" --timeout=40m
kubectl rollout status deployment/redis     -n "$NS" --timeout=5m

say "Starting the application tier"
kubectl apply -f "$M/20-orders.yaml" -f "$M/21-catalog.yaml" \
              -f "$M/22-bff.yaml"    -f "$M/23-web.yaml" -f "$M/24-loadgen.yaml"

for d in orders catalog bff web loadgen; do
  kubectl rollout status "deployment/$d" -n "$NS" --timeout=10m
done

# ------------------------------------------------------------------ datadog
say "Installing the Datadog Agent"
helm repo add datadog https://helm.datadoghq.com >/dev/null 2>&1 || true
helm repo update >/dev/null

kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic datadog-secret -n datadog \
  --from-literal=api-key="$DD_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

# Referenced from the DBM pod annotations as %%env_*%%, so the database
# passwords never appear in an application pod spec.
kubectl create secret generic "$DEMO_NAME-dbm" -n datadog \
  --from-literal=MYSQL_DD_PASSWORD="$MYSQL_DD_PASSWORD" \
  --from-literal=POSTGRES_DD_PASSWORD="$POSTGRES_DD_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

render k8s/datadog-values.yaml "$RENDERED/datadog-values.yaml"
helm upgrade --install datadog datadog/datadog \
  -n datadog \
  -f "$RENDERED/datadog-values.yaml" \
  --set datadog.site="$DD_SITE" \
  --set datadog.clusterName="$DEMO_NAME-kind" \
  --wait --timeout 10m

say "Done."
cat <<EOF

  Storefront      http://localhost:8080
  Control panel   http://localhost:8080/control.html
  BFF API         http://localhost:3000/api/health

  Pods            kubectl get pods -n $NS
  Agent status    kubectl exec -n datadog ds/datadog -c agent -- agent status
  DBM check       kubectl exec -n datadog ds/datadog -c agent -- agent check mysql

  Services in Datadog: $DEMO_NAME-web, $DEMO_NAME-bff, $DEMO_NAME-orders, $DEMO_NAME-catalog

EOF
